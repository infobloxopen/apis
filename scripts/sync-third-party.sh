#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

if ! command -v buf &>/dev/null; then
  echo "error: buf is required but not found (https://buf.build/docs/installation)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# BSR modules to vendor. buf export output is copied directly into proto/.
MODULES=(
  "buf.build/protocolbuffers/wellknowntypes"
)

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Sync third-party proto files from the Buf Schema Registry (BSR) into the
local proto/ directory so that consumers do not need buf to resolve imports.

Options:
  --check-only   Report what would change, then exit
  --module NAME  Only sync the named BSR module (default: all)
  -h, --help     Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --check-only
  $(basename "$0") --module buf.build/protocolbuffers/wellknowntypes
EOF
  exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

CHECK_ONLY=false
FILTER_MODULE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    --module)
      FILTER_MODULE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "error: unknown option $1" >&2
      usage
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Sync
# ---------------------------------------------------------------------------

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

DEST_DIR="$REPO_ROOT/proto"

for module in "${MODULES[@]}"; do
  if [[ -n "$FILTER_MODULE" && "$module" != "$FILTER_MODULE" ]]; then
    continue
  fi

  echo "Syncing $module -> proto/"

  # Export from BSR into a temp directory
  export_dir="$TMPDIR/export"
  rm -rf "$export_dir"
  mkdir -p "$export_dir"
  buf export "$module" -o "$export_dir"

  if $CHECK_ONLY; then
    # Compare exported files with what we have
    changed=false
    while IFS= read -r -d '' file; do
      rel="${file#"$export_dir/"}"
      target="$DEST_DIR/$rel"
      if [[ ! -f "$target" ]]; then
        echo "  + $rel (new)"
        changed=true
      elif ! diff -q "$file" "$target" &>/dev/null; then
        echo "  ~ $rel (modified)"
        changed=true
      fi
    done < <(find "$export_dir" -type f -print0)

    # Check for files we have that upstream removed
    while IFS= read -r -d '' file; do
      rel="${file#"$DEST_DIR/"}"
      # Only check paths that overlap with this export (e.g. google/)
      [[ "$rel" == *.proto ]] || continue
      if [[ ! -f "$export_dir/$rel" ]]; then
        echo "  - $rel (removed upstream)"
        changed=true
      fi
    done < <(find "$DEST_DIR/google" -type f -print0 2>/dev/null)

    if ! $changed; then
      echo "  (up to date)"
    fi
    continue
  fi

  # Copy exported files into the repo
  copied=0
  while IFS= read -r -d '' file; do
    rel="${file#"$export_dir/"}"
    target="$DEST_DIR/$rel"
    mkdir -p "$(dirname "$target")"
    cp "$file" "$target"
    echo "  + $rel"
    copied=$((copied + 1))
  done < <(find "$export_dir" -type f -print0)

  echo "  Copied $copied files"
done

if ! $CHECK_ONLY; then
  echo ""
  echo "Sync complete. Review changes with: git diff --stat"
fi
