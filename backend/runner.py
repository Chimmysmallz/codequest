"""Sandboxed-ish Python code runner for CodeQuest submissions.

================================ SECURITY ==================================
This runner uses OS-level protections only: an execution timeout, POSIX
resource limits (CPU / address space / open files), a fresh process session
so the whole group can be killed, an isolated temp working directory, and a
MINIMAL environment (the parent process env is NOT inherited).

It is NOT a hardened sandbox. Untrusted code can still read parts of the
filesystem, spin threads, and attempt other mischief within the limits above.
BEFORE accepting code from real/untrusted users, run every submission inside a
properly isolated environment:
  - an isolated container (Docker / gVisor),
  - a microVM (Firecracker), or
  - a jail (nsjail / firejail)
with NO network access and a READ-ONLY filesystem. Treat this module as a
development convenience, not a production security boundary.
===========================================================================
"""

import os
import subprocess
import sys
import tempfile
from typing import Optional

from config import settings

# Maximum combined (stdout + stderr) characters we return to the client.
MAX_OUTPUT_CHARS = 10_000

# Resource limit tunables (POSIX only).
_CPU_SECONDS = 2          # RLIMIT_CPU — hard CPU-time ceiling.
_ADDRESS_SPACE = 256 * 1024 * 1024  # RLIMIT_AS — 256 MB virtual memory.
_MAX_OPEN_FILES = 64      # RLIMIT_NOFILE.


def _preexec_limits():
    """Run in the child process just before exec (POSIX only).

    Starts a new session (so the whole process group can be killed on timeout)
    and applies resource limits. Guarded so it degrades gracefully where the
    `resource` module is unavailable (e.g. Windows).
    """
    # New session/process group: lets us kill everything the child spawns.
    try:
        os.setsid()
    except Exception:
        pass

    try:
        import resource
    except Exception:
        # No resource module (e.g. Windows) — rely on the subprocess timeout.
        return

    def _try_set(which, soft, hard):
        try:
            resource.setrlimit(which, (soft, hard))
        except Exception:
            # Some limits may be unsettable in certain environments; skip them.
            pass

    _try_set(resource.RLIMIT_CPU, _CPU_SECONDS, _CPU_SECONDS)
    _try_set(resource.RLIMIT_AS, _ADDRESS_SPACE, _ADDRESS_SPACE)
    _try_set(resource.RLIMIT_NOFILE, _MAX_OPEN_FILES, _MAX_OPEN_FILES)


def _kill_process_group(proc):
    """Best-effort kill of the child's whole process group."""
    try:
        os.killpg(os.getpgid(proc.pid), 9)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass


def _cap(text: str) -> str:
    """Cap output length so a runaway print loop can't flood the response."""
    if text is None:
        return ""
    if len(text) > MAX_OUTPUT_CHARS:
        return text[:MAX_OUTPUT_CHARS] + "\n... [output truncated]"
    return text


def run_subprocess(code: str, timeout_s: float = 3.0) -> dict:
    """Execute `code` as an isolated Python subprocess (the dev runner).

    Returns a dict: {"output": str, "error": str | None, "timedOut": bool}.
    `output` is captured stdout; `error` carries captured stderr (or a runner
    error message) when non-empty; `timedOut` is True if the wall-clock timeout
    tripped.
    """
    if code is None:
        code = ""

    # Fresh temp dir as the working directory — isolates any files the script
    # might write and gets cleaned up automatically.
    with tempfile.TemporaryDirectory(prefix="codequest_run_") as workdir:
        script_path = os.path.join(workdir, "submission.py")
        try:
            with open(script_path, "w", encoding="utf-8") as fh:
                fh.write(code)
        except OSError as exc:
            return {"output": "", "error": f"Could not stage code: {exc}", "timedOut": False}

        # MINIMAL environment — do NOT inherit the parent process env.
        env = {
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONIOENCODING": "utf-8",
            "PATH": "",  # nothing to find on PATH inside the script.
        }

        # -I: isolated mode (ignore env vars, user site, don't add cwd to path).
        # -S: skip the site module for a faster, leaner startup.
        cmd = [sys.executable, "-I", "-S", script_path]

        # preexec_fn only works on POSIX; on other platforms fall back to None.
        preexec = _preexec_limits if os.name == "posix" else None

        try:
            proc = subprocess.Popen(
                cmd,
                cwd=workdir,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=preexec,
                text=True,
            )
        except Exception as exc:
            return {"output": "", "error": f"Failed to start runner: {exc}", "timedOut": False}

        try:
            stdout, stderr = proc.communicate(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            _kill_process_group(proc)
            # Reap the process and collect whatever it managed to emit.
            try:
                stdout, stderr = proc.communicate(timeout=1.0)
            except Exception:
                stdout, stderr = "", ""
            return {
                "output": _cap(stdout or ""),
                "error": "Your code took too long to run.",
                "timedOut": True,
            }
        except Exception as exc:
            _kill_process_group(proc)
            return {"output": "", "error": f"Runner error: {exc}", "timedOut": False}

        stdout = _cap(stdout or "")
        stderr = _cap(stderr or "")
        error = stderr if stderr.strip() else None
        return {"output": stdout, "error": error, "timedOut": False}


def run_code(code: str, timeout_s: Optional[float] = None) -> dict:
    """Dispatch a code run to the configured sandbox backend.

    * SANDBOX_MODE == "docker"  -> hardened container sandbox (runner_docker).
    * anything else             -> the built-in subprocess runner above.

    The result shape is identical either way:
        {"output": str, "error": str | None, "timedOut": bool}.
    """
    if timeout_s is None:
        timeout_s = settings.RUN_TIMEOUT_S

    if settings.SANDBOX_MODE == "docker":
        # Imported lazily so local dev never needs the docker module/daemon.
        import runner_docker

        return runner_docker.run_docker(code, timeout_s)

    return run_subprocess(code, timeout_s)
