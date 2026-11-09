#!/usr/bin/env bash
# Run once after "Use this template": renames the placeholder app name and GitHub owner.
#   scripts/init.sh <app-name> [github-owner]
# Owner defaults to the owner parsed from `git remote get-url origin`.
set -euo pipefail

PLACEHOLDER_NAME="app-template"
PLACEHOLDER_OWNER="sockstabby"

NAME="${1:-}"
OWNER="${2:-}"

usage() { echo "usage: $0 <app-name> [github-owner]" >&2; exit 2; }
[ -n "$NAME" ] || usage

# DNS-1123 label: used as Helm release, k8s object names, and image name. Leave room for suffixes.
if ! [[ "$NAME" =~ ^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$ ]]; then
  echo "error: '$NAME' must be lowercase alphanumerics and '-', start with a letter, max 40 chars" >&2
  exit 1
fi

if [ -z "$OWNER" ]; then
  url="$(git remote get-url origin 2>/dev/null || true)"
  OWNER="$(sed -E 's#^(https://github.com/|git@github.com:)([^/]+)/.*#\2#' <<<"$url")"
  [ -n "$OWNER" ] && [ "$OWNER" != "$url" ] || { echo "error: could not infer owner; pass it explicitly" >&2; exit 1; }
fi
OWNER="$(tr '[:upper:]' '[:lower:]' <<<"$OWNER")"

cd "$(git rev-parse --show-toplevel 2>/dev/null || dirname "$0"/..)"

if [ "$NAME" = "$PLACEHOLDER_NAME" ]; then echo "nothing to do: name is already $NAME"; exit 0; fi
if ! grep -rq "$PLACEHOLDER_NAME" chart Makefile .github 2>/dev/null; then
  echo "already initialised (no '$PLACEHOLDER_NAME' placeholders left)"; exit 0
fi

# Files that carry placeholders. The platform workflow refs (sockstabby/platform@v1) are NOT
# rewritten: apps keep calling the shared platform repo.
files=(chart/Chart.yaml chart/values.yaml chart/values-*.yaml Makefile .github/workflows/*.yml README.md)

for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  # image path owner first (ghcr.io/<owner>/<name>), then the bare name everywhere
  sed -i.bak -E \
    -e "s#ghcr.io/${PLACEHOLDER_OWNER}/${PLACEHOLDER_NAME}#ghcr.io/${OWNER}/${NAME}#g" \
    -e "s#(^|[^/a-z0-9-])${PLACEHOLDER_NAME}([^a-z0-9-]|$)#\1${NAME}\2#g" \
    "$f"
  rm -f "$f.bak"
done

echo "initialised: name=$NAME owner=$OWNER"
echo "next: review 'git diff', commit, and create GitHub Environments 'debug' and 'production'."
