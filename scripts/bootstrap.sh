#!/usr/bin/env bash
set -euo pipefail

ENGINE_URL=""
ANDROID_URL=""
ENGINE_DIR="engine"
ANDROID_DIR="android"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)
      ENGINE_URL="$2"
      shift 2
      ;;
    --android)
      ANDROID_URL="$2"
      shift 2
      ;;
    --engine-dir)
      ENGINE_DIR="$2"
      shift 2
      ;;
    --android-dir)
      ANDROID_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ENGINE_URL" || -z "$ANDROID_URL" ]]; then
  echo "Usage: $0 --engine <git_url> --android <git_url>" >&2
  exit 2
fi

command -v git >/dev/null 2>&1 || { echo "git not found." >&2; exit 1; }

if [[ ! -e "$ENGINE_DIR" ]]; then
  git submodule add "$ENGINE_URL" "$ENGINE_DIR"
else
  echo "Exists: $ENGINE_DIR (skipping add)"
fi

if [[ ! -e "$ANDROID_DIR" ]]; then
  git submodule add "$ANDROID_URL" "$ANDROID_DIR"
else
  echo "Exists: $ANDROID_DIR (skipping add)"
fi

git submodule update --init --recursive

cat <<'EOF'

Next steps:
1) Copy template game: template/game/* -> android/app/src/embed/assets/
2) Open android/ in Android Studio and run.

EOF

