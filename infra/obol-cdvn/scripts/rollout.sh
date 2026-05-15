#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  rollout.sh --render-dir <bundle-or-runtime-path> [--host-name <name>] --approval-file <path> [--destination <path>] [--include-charon-artifacts] [--execute]

Examples:
  ./rollout.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --approval-file ./rollout-approval.example.env
  ./rollout.sh --render-dir /tmp/cdvn-operator-1-runtime --approval-file ./rollout-approval.example.env --destination /opt/obol/cluster-a
  ./rollout.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --approval-file ./approval.env --destination ubuntu@203.0.113.11:/opt/obol/cluster-a --execute
EOF
}

RENDER_DIR=""
HOST_NAME=""
APPROVAL_FILE=""
DESTINATION=""
EXECUTE=0
INCLUDE_CHARON_ARTIFACTS=0

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
    --approval-file)
      APPROVAL_FILE="${2:-}"
      shift 2
      ;;
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --execute)
      EXECUTE=1
      shift
      ;;
    --include-charon-artifacts)
      INCLUDE_CHARON_ARTIFACTS=1
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
[ -n "${APPROVAL_FILE}" ] || { usage >&2; exit 1; }

HOST_RUNTIME_DIR="$(resolve_runtime_dir_arg "${RENDER_DIR}" "${HOST_NAME}")" || exit 1
HOST_NAME="$(resolve_host_name_arg "${HOST_RUNTIME_DIR}" "${HOST_NAME}")" || exit 1
METADATA_FILE="$(runtime_metadata_file "${HOST_RUNTIME_DIR}")"
validate_rollout_approval "${APPROVAL_FILE}" "${METADATA_FILE}" "${HOST_NAME}"

DEPLOYMENT_PATH="$(read_env_value "${METADATA_FILE}" "DEPLOYMENT_PATH")"

if [ -z "${DESTINATION}" ]; then
  DESTINATION="${DEPLOYMENT_PATH}"
fi

if [ -z "${DESTINATION}" ]; then
  echo "Destination is required when render metadata has no deployment path." >&2
  exit 1
fi

RSYNC_EXCLUDES=(--exclude data/ --exclude jwt/jwt.hex)
if [ "${INCLUDE_CHARON_ARTIFACTS}" -ne 1 ]; then
  RSYNC_EXCLUDES+=(--exclude .charon/ --exclude charon-artifacts-staging.env --exclude validator-pubkeys.txt)
fi

RSYNC_ARGS=(-a --delete "${RSYNC_EXCLUDES[@]}")
if [ "${EXECUTE}" -ne 1 ]; then
  RSYNC_ARGS=(-ain --delete "${RSYNC_EXCLUDES[@]}")
fi

echo "Rollout target: ${DESTINATION}"
echo "Approval file: ${APPROVAL_FILE}"
echo "Runtime dir: ${HOST_RUNTIME_DIR}"
if [ "${INCLUDE_CHARON_ARTIFACTS}" -ne 1 ]; then
  echo "Charon artifacts: excluded; stage them on the operator host with stage-charon-artifacts.sh --runtime-dir."
else
  echo "Charon artifacts: included by explicit override."
fi

rsync "${RSYNC_ARGS[@]}" "${HOST_RUNTIME_DIR}/" "${DESTINATION}/"
