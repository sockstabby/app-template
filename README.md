# app-template

GitHub template for a small FastAPI service deployed to EKS with Helm.
CI/CD logic lives in [`sockstabby/platform`](https://github.com/sockstabby/platform) reusable workflows (`@v1`).

> Full README (create-from-template, local kind loop, debug → prod promotion) is written in Phase 7.

## Quick start (local)

```sh
make venv test        # unit tests
make all              # kind-up → build → deploy-local → smoke (expects /healthz 200)
make kind-down
```
