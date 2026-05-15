#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  drift-check.sh --render-dir <bundle-or-runtime-path> [--host-name <name>] --destination <path> [--fail-on-drift]

Examples:
  ./drift-check.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --destination /srv/cdvn/operator-1
  ./drift-check.sh --render-dir /tmp/cdvn-operator-1-runtime --destination /srv/cdvn/operator-1
EOF
}

RENDER_DIR=""
HOST_NAME=""
DESTINATION=""
FAIL_ON_DRIFT=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --render-dir)
      RENDER_DIR="${2:-}"
      shift 2
      ;;
    --host-name)
      HOST_NAME="${2:-}"
      shift 2
      ;;
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --fail-on-drift)
      FAIL_ON_DRIFT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[ -n "${RENDER_DIR}" ] || { usage >&2; exit 1; }
[ -n "${DESTINATION}" ] || { usage >&2; exit 1; }

HOST_RUNTIME_DIR="$(resolve_runtime_dir_arg "${RENDER_DIR}" "${HOST_NAME}")" || exit 1
HOST_NAME="$(resolve_host_name_arg "${HOST_RUNTIME_DIR}" "${HOST_NAME}")" || exit 1

DRIFT_OUTPUT="$(rsync -ain --delete --exclude data/ --exclude .charon/ --exclude charon-artifacts-staging.env --exclude validator-pubkeys.txt --exclude jwt/jwt.hex "${HOST_RUNTIME_DIR}/" "${DESTINATION}/" || true)"

if [ -z "${DRIFT_OUTPUT}" ]; then
  echo "No drift detected for ${HOST_NAME}"
  exit 0
fi

printf '%s\n' "${DRIFT_OUTPUT}"
if [ "${FAIL_ON_DRIFT}" -eq 1 ]; then
  exit 2
fi
