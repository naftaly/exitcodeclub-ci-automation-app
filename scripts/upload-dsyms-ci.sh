#!/bin/bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: upload-dsyms-ci.sh --backend-url URL [--archive-path PATH | --dsym-folder PATH]
USAGE
}

BACKEND_URL=""
ARCHIVE_PATH=""
DSYM_FOLDER=""
RETRIES=3
RETRY_DELAY=2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend-url) BACKEND_URL="${2:-}"; shift 2 ;;
    --archive-path) ARCHIVE_PATH="${2:-}"; shift 2 ;;
    --dsym-folder) DSYM_FOLDER="${2:-}"; shift 2 ;;
    --retries) RETRIES="${2:-}"; shift 2 ;;
    --retry-delay) RETRY_DELAY="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$BACKEND_URL" ]]; then
  echo "error: --backend-url is required" >&2
  exit 1
fi

if [[ -n "$ARCHIVE_PATH" && -n "$DSYM_FOLDER" ]]; then
  echo "error: use only one of --archive-path or --dsym-folder" >&2
  exit 1
fi

if [[ -z "$ARCHIVE_PATH" && -z "$DSYM_FOLDER" ]]; then
  echo "error: one of --archive-path or --dsym-folder is required" >&2
  exit 1
fi

if [[ -n "$ARCHIVE_PATH" ]]; then
  DSYM_FOLDER="$ARCHIVE_PATH/dSYMs"
fi

if [[ ! -d "$DSYM_FOLDER" ]]; then
  echo "error: dSYM folder not found: $DSYM_FOLDER" >&2
  exit 1
fi

if [[ "$BACKEND_URL" == */api/reports ]]; then
  BACKEND_URL="${BACKEND_URL%/api/reports}"
fi
if [[ "$BACKEND_URL" == */ ]]; then
  BACKEND_URL="${BACKEND_URL%/}"
fi

DSYM_PATHS=()
while IFS= read -r -d '' dsym_path; do
  DSYM_PATHS+=("$dsym_path")
done < <(find "$DSYM_FOLDER" -name "*.dSYM" -type d -print0 2>/dev/null)
if [[ ${#DSYM_PATHS[@]} -eq 0 ]]; then
  echo "No dSYMs found, skipping upload"
  exit 0
fi

VALID_DSYMS=()
for dsym in "${DSYM_PATHS[@]}"; do
  dwarf_dir="$dsym/Contents/Resources/DWARF"
  [[ -d "$dwarf_dir" ]] || continue
  for bin in "$dwarf_dir"/*; do
    [[ -f "$bin" ]] || continue
    if xcrun dwarfdump --uuid "$bin" 2>/dev/null | grep -q "UUID:"; then
      VALID_DSYMS+=("$dsym")
      break
    fi
  done
done

if [[ ${#VALID_DSYMS[@]} -eq 0 ]]; then
  echo "error: no valid dSYMs with UUIDs found" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
ZIP_FILE="$WORK_DIR/dsyms.zip"

(
  cd "$DSYM_FOLDER"
  for dsym in "${VALID_DSYMS[@]}"; do
    rel="${dsym#$DSYM_FOLDER/}"
    zip -rq "$ZIP_FILE" "$rel" 2>/dev/null || zip -rq "$ZIP_FILE" "$(basename "$dsym")" 2>/dev/null
  done
)

ATTEMPT=1
LAST_CODE="000"
LAST_BODY=""
while [[ $ATTEMPT -le $RETRIES ]]; do
  RESPONSE="$(curl -sS -w '\n%{http_code}' -X POST -F "file=@$ZIP_FILE" "$BACKEND_URL/api/dsyms" || true)"
  HTTP_CODE="$(echo "$RESPONSE" | tail -1)"
  BODY="$(echo "$RESPONSE" | sed '$d')"
  LAST_CODE="$HTTP_CODE"
  LAST_BODY="$BODY"

  if [[ "$HTTP_CODE" == "200" ]]; then
    echo "dSYM upload succeeded"
    exit 0
  fi

  if [[ $ATTEMPT -lt $RETRIES ]]; then
    sleep_seconds=$((RETRY_DELAY * ATTEMPT))
    echo "Attempt $ATTEMPT failed (HTTP $HTTP_CODE). Retrying in ${sleep_seconds}s..."
    sleep "$sleep_seconds"
  fi

  ATTEMPT=$((ATTEMPT + 1))
done

echo "error: dSYM upload failed after $RETRIES attempts (HTTP $LAST_CODE)" >&2
[[ -n "$LAST_BODY" ]] && echo "$LAST_BODY" >&2
exit 1
