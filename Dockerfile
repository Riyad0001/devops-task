# syntax=docker/dockerfile:1

# ---------- Stage 1: build dependencies in an isolated virtualenv ----------
FROM python:3.12-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /build
# Copy only the requirements first so this layer is cached until deps change.
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# ---------- Stage 2: small runtime image ----------
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Run as an unprivileged user, not root.
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

# Only the ready-made virtualenv and the app code reach the final image.
COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app app/main.py .

USER app

EXPOSE 8080

# python:slim has no curl, so use the standard library for the health probe.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request as u; u.urlopen('http://127.0.0.1:8080/', timeout=2)"]

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--access-logfile", "-", "main:app"]
