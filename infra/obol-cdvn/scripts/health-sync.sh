#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  health-sync.sh --render-dir <bundle-or-runtime-path> [--host-name <name>] [--endpoint-url <url>] [--dry-run]

Examples:
  ./health-sync.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --dry-run
  ./health-sync.sh --render-dir /opt/obol/cluster-a --dry-run
EOF
}

RENDER_DIR=""
HOST_NAME=""
ENDPOINT_URL=""
DRY_RUN=0

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
    --endpoint-url)
      ENDPOINT_URL="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
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

HOST_RUNTIME_DIR="$(resolve_runtime_dir_arg "${RENDER_DIR}" "${HOST_NAME}")" || exit 1
HOST_NAME="$(resolve_host_name_arg "${HOST_RUNTIME_DIR}" "${HOST_NAME}")" || exit 1
METADATA_FILE="$(runtime_metadata_file "${HOST_RUNTIME_DIR}")"
[ -f "${METADATA_FILE}" ] || { echo "Render metadata not found: ${METADATA_FILE}" >&2; exit 1; }

CLUSTER_NAME="$(read_env_value "${METADATA_FILE}" "CLUSTER_NAME")"
NETWORK="$(read_env_value "${METADATA_FILE}" "NETWORK")"
HOST_ADDRESS="$(read_env_value "${METADATA_FILE}" "HOST_ADDRESS")"
BASELINE_REF="$(read_env_value "${METADATA_FILE}" "BASELINE_REF")"
OVERLAY_PROFILES="$(read_env_value "${METADATA_FILE}" "OVERLAY_PROFILES")"
RENDERED_AT="$(read_env_value "${METADATA_FILE}" "RENDERED_AT")"

if [ -z "${ENDPOINT_URL}" ]; then
  ENDPOINT_URL="$(read_env_value "${METADATA_FILE}" "HEALTH_SYNC_URL")"
fi

if [ -z "${ENDPOINT_URL}" ]; then
  echo "No health sync endpoint configured." >&2
  exit 1
fi

PAYLOAD="$(cat <<EOF
{"clusterName":"${CLUSTER_NAME}","hostName":"${HOST_NAME}","hostAddress":"${HOST_ADDRESS}","network":"${NETWORK}","baselineRef":"${BASELINE_REF}","overlayProfiles":"${OVERLAY_PROFILES}","renderedAt":"${RENDERED_AT}"}
EOF
)"

if [ "${DRY_RUN}" -eq 1 ]; then
  echo "POST ${ENDPOINT_URL}"
  printf '%s\n' "${PAYLOAD}"
  exit 0
fi

curl -sS -X POST -H 'content-type: application/json' --data "${PAYLOAD}" "${ENDPOINT_URL}"
