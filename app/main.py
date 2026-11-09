"""Minimal service used to demonstrate the platform's build/deploy pipeline."""

import os

from fastapi import FastAPI

APP_NAME = os.getenv("APP_NAME", "app-template")
APP_VERSION = os.getenv("APP_VERSION", "dev")
APP_ENV = os.getenv("APP_ENV", "local")

app = FastAPI(title=APP_NAME, version=APP_VERSION)


@app.get("/")
def root() -> dict[str, str]:
    return {"message": f"hello from {APP_NAME}", "environment": APP_ENV}


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/version")
def version() -> dict[str, str]:
    return {"version": APP_VERSION}
