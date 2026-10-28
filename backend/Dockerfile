# Backend API image (for deployment). This runs the FastAPI app itself — it is
# NOT the code sandbox (that's sandbox/Dockerfile).
FROM python:3.12-slim

# Don't buffer stdout/stderr; don't write .pyc files.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Install dependencies first so this layer caches unless requirements change.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application source.
COPY . .

EXPOSE 8000

# Serve the API. Override DATABASE_URL / JWT_SECRET / SANDBOX_MODE via env.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
