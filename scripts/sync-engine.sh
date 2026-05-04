#!/usr/bin/env bash
set -euo pipefail

ANDROID_DIR="${1:-android}"
ENGINE_URL="${2:-}"
LOVE_SUBPATH="${3:-app/src/main/cpp/love}"

if [[ -z "$ENGINE_URL" ]]; then
  ENGINE_URL="$(git config --get remote.origin.url || true)"
fi

if [[ -z "$ENGINE_URL" ]]; then
  echo "Engine URL not provided and couldn't infer from remote.origin.url" >&2
  echo "Usage: $0 [android_dir] <engine_git_url> [love_submodule_path]" >&2
  exit 2
fi

echo "Pointing $ANDROID_DIR/$LOVE_SUBPATH -> $ENGINE_URL"

git -C "$ANDROID_DIR" submodule set-url "$LOVE_SUBPATH" "$ENGINE_URL"
git -C "$ANDROID_DIR" submodule update --init --recursive "$LOVE_SUBPATH"

echo "Done."

