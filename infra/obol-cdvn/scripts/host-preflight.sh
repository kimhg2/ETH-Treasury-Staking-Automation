#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  host-preflight.sh --render-dir <bundle-or-runtime-path> [--host-name <name>] [--ssh-target <user@host>] [--deployment-path <path>] [--required-file <path>]... [--min-disk-gb <n>] [--check-web3signer] [--local] [--execute]

Examples:
  ./host-preflight.sh --render-dir /tmp/cdvn-bundle --host-name operator-1
  ./host-preflight.sh --render-dir /tmp/cdvn-operator-1-runtime --local
  ./host-preflight.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --ssh-target ubuntu@203.0.113.11 --execute
  ./host-preflight.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --local --execute
EOF
}

RENDER_DIR=""
HOST_NAME=""
SSH_TARGET=""
DEPLOYMENT_PATH=""
MIN_DISK_GB=20
CHECK_WEB3SIGNER=0
LOCAL_MODE=0
EXECUTE=0
REQUIRED_FILES=()
REQUIRED_FILE_COUNT=0

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
    --ssh-target)
      SSH_TARGET="${2:-}"
      shift 2
      ;;
    --deployment-path)
      DEPLOYMENT_PATH="${2:-}"
      shift 2
      ;;
    --required-file)
      REQUIRED_FILES+=("${2:-}")
      REQUIRED_FILE_COUNT=$((REQUIRED_FILE_COUNT + 1))
      shift 2
      ;;
    --min-disk-gb)
      MIN_DISK_GB="${2:-}"
      shift 2
      ;;
    --check-web3signer)
      CHECK_WEB3SIGNER=1
      shift
      ;;
    --local)
      LOCAL_MODE=1
      shift
      ;;
    --execute)
      EXECUTE=1
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

case "${MIN_DISK_GB}" in
  ""|*[!0-9]*)
    echo "--min-disk-gb must be an integer." >&2
    exit 1
    ;;
esac

HOST_RUNTIME_DIR="$(resolve_runtime_dir_arg "${RENDER_DIR}" "${HOST_NAME}")" || exit 1
HOST_NAME="$(resolve_host_name_arg "${HOST_RUNTIME_DIR}" "${HOST_NAME}")" || exit 1
METADATA_FILE="$(runtime_metadata_file "${HOST_RUNTIME_DIR}")"
ENV_FILE="$(runtime_env_file "${HOST_RUNTIME_DIR}")"

if [ -z "${DEPLOYMENT_PATH}" ]; then
  DEPLOYMENT_PATH="$(read_env_value "${METADATA_FILE}" "DEPLOYMENT_PATH")"
fi

[ -n "${DEPLOYMENT_PATH}" ] || {
  echo "Deployment path is required. Pass --deployment-path or set DEPLOYMENT_PATH in render metadata." >&2
  exit 1
}

if [ "${LOCAL_MODE}" -ne 1 ]; then
  SSH_TARGET="$(resolve_ssh_target_from_metadata "${METADATA_FILE}" "${SSH_TARGET}")" || {
    echo "No SSH target configured. Pass --ssh-target or render metadata with SSH_USER/HOST_ADDRESS." >&2
    exit 1
  }
fi

MIN_DISK_KB=$((MIN_DISK_GB * 1024 * 1024))
WEB3SIGNER_URL="$(read_env_value "${ENV_FILE}" "WEB3SIGNER_URL" || true)"
REQUIRED_FILE_CHECKS=""

if [ "${REQUIRED_FILE_COUNT}" -gt 0 ]; then
  for required_file in "${REQUIRED_FILES[@]}"; do
    REQUIRED_FILE_CHECKS="${REQUIRED_FILE_CHECKS}
[ -e $(shell_quote "${required_file}") ] || { echo \"Missing required file: ${required_file}\" >&2; exit 1; }"
  done
fi

WEB3SIGNER_CHECK=""
if [ "${CHECK_WEB3SIGNER}" -eq 1 ] && [ -n "${WEB3SIGNER_URL}" ]; then
  WEB3SIGNER_CHECK="${WEB3SIGNER_CHECK}
curl -fsS --max-time 5 $(shell_quote "${WEB3SIGNER_URL%/}/upcheck") >/dev/null || { echo \"Web3Signer upcheck failed: ${WEB3SIGNER_URL%/}/upcheck\" >&2; exit 1; }"
fi

REMOTE_SCRIPT="$(cat <<EOF
set -euo pipefail
DEPLOYMENT_PATH=$(shell_quote "${DEPLOYMENT_PATH}")
MIN_DISK_KB=${MIN_DISK_KB}

command -v docker >/dev/null || { echo "docker not found" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose not available" >&2; exit 1; }
command -v rsync >/dev/null || { echo "rsync not found" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl not found" >&2; exit 1; }

mkdir -p "\${DEPLOYMENT_PATH}" "\${DEPLOYMENT_PATH}/data" "\${DEPLOYMENT_PATH}/jwt" "\${DEPLOYMENT_PATH}/.charon"
[ -w "\${DEPLOYMENT_PATH}" ] || { echo "Deployment path is not writable: \${DEPLOYMENT_PATH}" >&2; exit 1; }

AVAILABLE_KB="\$(df -Pk "\${DEPLOYMENT_PATH}" | awk 'NR==2 {print \$4}')"
[ -n "\${AVAILABLE_KB}" ] || { echo "Failed to read free disk for \${DEPLOYMENT_PATH}" >&2; exit 1; }
[ "\${AVAILABLE_KB}" -ge "\${MIN_DISK_KB}" ] || { echo "Insufficient disk space on \${DEPLOYMENT_PATH}: \${AVAILABLE_KB}KB < \${MIN_DISK_KB}KB" >&2; exit 1; }
${REQUIRED_FILE_CHECKS}
${WEB3SIGNER_CHECK}
echo "Preflight passed for \${DEPLOYMENT_PATH}"
EOF
)"

echo "Preflight host: ${HOST_NAME}"
echo "Deployment path: ${DEPLOYMENT_PATH}"
echo "Mode: $([ "${EXECUTE}" -eq 1 ] && printf 'execute' || printf 'dry-run')"
if [ "${LOCAL_MODE}" -eq 1 ]; then
  echo "Target: local"
else
  echo "SSH target: ${SSH_TARGET}"
fi

if [ "${EXECUTE}" -ne 1 ]; then
  echo "Planned checks:"
  echo "- docker present"
  echo "- docker compose present"
  echo "- rsync present"
  echo "- curl present"
  echo "- deployment path writable"
  echo "- minimum free disk ${MIN_DISK_GB}GB"
  if [ "${REQUIRED_FILE_COUNT}" -gt 0 ]; then
    echo "- required files exist"
  fi
  if [ "${CHECK_WEB3SIGNER}" -eq 1 ] && [ -n "${WEB3SIGNER_URL}" ]; then
    echo "- Web3Signer upcheck reachable"
  fi
  echo "Command preview:"
  printf '%s\n' "${REMOTE_SCRIPT}"
  exit 0
fi

if [ "${LOCAL_MODE}" -eq 1 ]; then
  bash -lc "${REMOTE_SCRIPT}"
  exit 0
fi

ssh -o BatchMode=yes "${SSH_TARGET}" "bash -lc $(shell_quote "${REMOTE_SCRIPT}")"
