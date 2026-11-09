# syntax=docker/dockerfile:1
# Base image tag verified on Docker Hub 2026-11-09.
ARG PYTHON_IMAGE=python:3.15.2-slim-trixie

# ---- builder: install deps into an isolated virtualenv ----
FROM ${PYTHON_IMAGE} AS builder
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY app/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# ---- runtime: copy only the venv + app, run as non-root ----
FROM ${PYTHON_IMAGE}
ARG APP_VERSION=dev
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION}
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
WORKDIR /srv
COPY --from=builder /opt/venv /opt/venv
COPY app/__init__.py app/main.py ./app/
USER 10001:10001
EXPOSE 8080
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]
