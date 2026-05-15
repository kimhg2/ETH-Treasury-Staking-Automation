#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  rollout-exec.sh --render-dir <bundle-or-runtime-path> [--host-name <name>] --approval-file <path> [--ssh-target <user@host>] [--deployment-path <path>] [--local] [--skip-pull] [--skip-up] [--skip-health-check] [--execute]

Examples:
  ./rollout-exec.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --approval-file ./rollout-approval.example.env
  ./rollout-exec.sh --render-dir /tmp/cdvn-operator-1-runtime --approval-file ./rollout-approval.example.env --local
  ./rollout-exec.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --approval-file ./approval.env --ssh-target ubuntu@203.0.113.11 --execute
EOF
}

RENDER_DIR=""
HOST_NAME=""
APPROVAL_FILE=""
SSH_TARGET=""
DEPLOYMENT_PATH=""
LOCAL_MODE=0
SKIP_PULL=0
SKIP_UP=0
SKIP_HEALTH_CHECK=0
EXECUTE=0

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
    --ssh-target)
      SSH_TARGET="${2:-}"
      shift 2
      ;;
    --deployment-path)
      DEPLOYMENT_PATH="${2:-}"
      shift 2
      ;;
    --local)
      LOCAL_MODE=1
      shift
      ;;
    --skip-pull)
      SKIP_PULL=1
      shift
      ;;
    --skip-up)
      SKIP_UP=1
      shift
      ;;
    --skip-health-check)
      SKIP_HEALTH_CHECK=1
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
[ -n "${APPROVAL_FILE}" ] || { usage >&2; exit 1; }

HOST_RUNTIME_DIR="$(resolve_runtime_dir_arg "${RENDER_DIR}" "${HOST_NAME}")" || exit 1
HOST_NAME="$(resolve_host_name_arg "${HOST_RUNTIME_DIR}" "${HOST_NAME}")" || exit 1
METADATA_FILE="$(runtime_metadata_file "${HOST_RUNTIME_DIR}")"
validate_rollout_approval "${APPROVAL_FILE}" "${METADATA_FILE}" "${HOST_NAME}"

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

PULL_BLOCK=""
if [ "${SKIP_PULL}" -ne 1 ]; then
  PULL_BLOCK='docker compose pull'
fi

UP_BLOCK=""
if [ "${SKIP_UP}" -ne 1 ]; then
  UP_BLOCK='docker compose up -d'
fi

HEALTH_BLOCK=""
if [ "${SKIP_HEALTH_CHECK}" -ne 1 ]; then
  HEALTH_BLOCK="$(cat <<'EOF'
docker compose ps
EXITED_SERVICES="$(docker compose ps --status exited --services 2>/dev/null || true)"
if [ -n "${EXITED_SERVICES}" ]; then
  echo "Exited compose services detected:" >&2
  printf '%s\n' "${EXITED_SERVICES}" >&2
  exit 1
fi
DEAD_SERVICES="$(docker compose ps --status dead --services 2>/dev/null || true)"
if [ -n "${DEAD_SERVICES}" ]; then
  echo "Dead compose services detected:" >&2
  printf '%s\n' "${DEAD_SERVICES}" >&2
  exit 1
fi
RUNNING_COUNT="$(docker compose ps --status running --services 2>/dev/null | awk 'NF {count += 1} END {print count + 0}')"
if [ "${RUNNING_COUNT}" -eq 0 ]; then
  echo "No running compose services detected." >&2
  exit 1
fi
EOF
)"
fi

REMOTE_SCRIPT="$(cat <<EOF
set -euo pipefail
DEPLOYMENT_PATH=$(shell_quote "${DEPLOYMENT_PATH}")

cd "\${DEPLOYMENT_PATH}"
docker compose config >/dev/null
${PULL_BLOCK}
${UP_BLOCK}
${HEALTH_BLOCK}
echo "Rollout execution completed for \${DEPLOYMENT_PATH}"
EOF
)"

echo "Rollout execute host: ${HOST_NAME}"
echo "Deployment path: ${DEPLOYMENT_PATH}"
echo "Mode: $([ "${EXECUTE}" -eq 1 ] && printf 'execute' || printf 'dry-run')"
if [ "${LOCAL_MODE}" -eq 1 ]; then
  echo "Target: local"
else
  echo "SSH target: ${SSH_TARGET}"
fi

if [ "${EXECUTE}" -ne 1 ]; then
  echo "Planned steps:"
  echo "- docker compose config"
  if [ "${SKIP_PULL}" -ne 1 ]; then
    echo "- docker compose pull"
  fi
  if [ "${SKIP_UP}" -ne 1 ]; then
    echo "- docker compose up -d"
  fi
  if [ "${SKIP_HEALTH_CHECK}" -ne 1 ]; then
    echo "- docker compose ps health check"
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
