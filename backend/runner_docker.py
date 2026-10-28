"""Hardened Docker sandbox for running untrusted CodeQuest submissions.

============================== SECURITY ===================================
This is the runner you should use when accepting code from real/untrusted
users. Each submission runs in a throwaway container with:

  --network=none        no network access at all
  --read-only           the container filesystem is read-only
  --memory=256m         hard memory cap
  --cpus=0.5            half a CPU
  --pids-limit=64       can't fork-bomb
  --user 65534:65534    runs as `nobody`, never root
  --tmpfs /tmp ...      a small, noexec scratch space for /tmp
  -v <tmpdir>:/code:ro  the user's code is mounted read-only
  python -I -S          isolated interpreter, no site customization

REQUIREMENTS: a running Docker daemon AND the sandbox image built from
``sandbox/Dockerfile``:

    docker build -t codequest-sandbox ./sandbox

Enable it by setting ``SANDBOX_MODE=docker`` (see config.py). If Docker is not
available this returns a friendly error dict rather than raising.
===========================================================================
"""

import os
import subprocess
import tempfile

from config import settings

# Maximum combined characters we return to the client (mirror runner.py).
MAX_OUTPUT_CHARS = 10_000


def _cap(text: str) -> str:
    """Cap output length so a runaway print loop can't flood the response."""
    if text is None:
        return ""
    if len(text) > MAX_OUTPUT_CHARS:
        return text[:MAX_OUTPUT_CHARS] + "\n... [output truncated]"
    return text


def run_docker(code: str, timeout_s: float) -> dict:
    """Run `code` inside the hardened sandbox container.

    Returns {"output": str, "error": str | None, "timedOut": bool}, matching
    the subprocess runner's contract exactly.
    """
    if code is None:
        code = ""

    # Stage the code in a host temp dir; we mount it read-only into the
    # container at /code, so the untrusted process can't modify its own source.
    with tempfile.TemporaryDirectory(prefix="codequest_docker_") as workdir:
        script_path = os.path.join(workdir, "main.py")
        try:
            with open(script_path, "w", encoding="utf-8") as fh:
                fh.write(code)
        except OSError as exc:
            return {"output": "", "error": f"Could not stage code: {exc}", "timedOut": False}

        cmd = [
            "docker", "run", "--rm",
            "--network=none",              # no network
            "--read-only",                 # read-only container filesystem
            "--memory=256m",               # memory ceiling
            "--cpus=0.5",                  # CPU ceiling
            "--pids-limit=64",             # no fork bombs
            "--user", "65534:65534",       # run as nobody, never root
            "--tmpfs", "/tmp:rw,size=8m,noexec",  # small scratch, no exec
            "-v", f"{workdir}:/code:ro",   # code mounted read-only
            settings.SANDBOX_IMAGE,
            "python", "-I", "-S", "/code/main.py",
        ]

        # We give docker itself a little extra wall-clock over the inner timeout
        # to account for container startup, then hard-kill on our own timeout.
        try:
            proc = subprocess.run(
                cmd,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=timeout_s + 5.0,
            )
        except subprocess.TimeoutExpired:
            # `docker run --rm` cleans up the container when the CLI is killed.
            return {
                "output": "",
                "error": "Your code took too long to run.",
                "timedOut": True,
            }
        except FileNotFoundError:
            # Docker CLI not installed / not on PATH.
            return {
                "output": "",
                "error": (
                    "Docker sandbox is not available (docker command not found). "
                    "Build the image and start the daemon, or set "
                    "SANDBOX_MODE=subprocess for local development."
                ),
                "timedOut": False,
            }
        except Exception as exc:
            return {"output": "", "error": f"Sandbox error: {exc}", "timedOut": False}

        stdout = _cap(proc.stdout or "")
        stderr = _cap(proc.stderr or "")
        error = stderr if stderr.strip() else None
        return {"output": stdout, "error": error, "timedOut": False}
