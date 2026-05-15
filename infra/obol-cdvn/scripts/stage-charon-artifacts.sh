#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  stage-charon-artifacts.sh --runtime-dir <path> --approval-file <path> --source-dir <path> [--host-name <name>] [--cluster-lock-file <path>] [--enr-file <path>] [--pubkeys-file <path>] [--force] [--execute]
  stage-charon-artifacts.sh --render-dir <path> --host-name <name> --approval-file <path> --source-dir <path> [--cluster-lock-file <path>] [--enr-file <path>] [--pubkeys-file <path>] [--force] [--execute] [--allow-render-dir-execute]

Examples:
  ./stage-charon-artifacts.sh --runtime-dir /opt/obol/cluster-a --approval-file ./charon-artifact-approval.env --source-dir /var/lib/eth-treasury-operator-artifacts/cluster-a --execute
  ./stage-charon-artifacts.sh --render-dir /tmp/cdvn-bundle --host-name operator-1 --approval-file ./charon-artifact-approval.example.env --source-dir /tmp/cdvn-local-approved/operator-1
EOF
}

RENDER_DIR=""
RUNTIME_DIR=""
HOST_NAME=""
APPROVAL_FILE=""
SOURCE_DIR=""
CLUSTER_LOCK_FILE=""
ENR_FILE=""
PUBKEYS_FILE=""
FORCE=0
EXECUTE=0
ALLOW_RENDER_DIR_EXECUTE=0
ALLOW_SENSITIVE_SOURCE_DIR=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --render-dir)
      RENDER_DIR="${2:-}"
      shift 2
      ;;
    --runtime-dir)
      RUNTIME_DIR="${2:-}"
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
    --source-dir)
      SOURCE_DIR="${2:-}"
      shift 2
      ;;
    --cluster-lock-file)
      CLUSTER_LOCK_FILE="${2:-}"
      shift 2
      ;;
    --enr-file)
      ENR_FILE="${2:-}"
      shift 2
      ;;
    --pubkeys-file)
      PUBKEYS_FILE="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --execute)
      EXECUTE=1
      shift
      ;;
    --allow-render-dir-execute)
      ALLOW_RENDER_DIR_EXECUTE=1
      shift
      ;;
    --allow-sensitive-source-dir)
      ALLOW_SENSITIVE_SOURCE_DIR=1
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

[ -n "${RENDER_DIR}" ] || [ -n "${RUNTIME_DIR}" ] || { usage >&2; exit 1; }
if [ -n "${RENDER_DIR}" ] && [ -n "${RUNTIME_DIR}" ]; then
  echo "Use either --render-dir or --runtime-dir, not both." >&2
  exit 1
fi
[ -n "${APPROVAL_FILE}" ] || { usage >&2; exit 1; }
[ -n "${SOURCE_DIR}" ] || { usage >&2; exit 1; }
[ -d "${SOURCE_DIR}" ] || { echo "Source dir not found: ${SOURCE_DIR}" >&2; exit 1; }

TARGET_MODE="runtime-dir"
if [ -n "${RENDER_DIR}" ]; then
  [ -n "${HOST_NAME}" ] || { echo "--host-name is required with --render-dir." >&2; usage >&2; exit 1; }
  TARGET_MODE="render-dir"
  require_rendered_host "${RENDER_DIR}" "${HOST_NAME}"
  HOST_RUNTIME_DIR="$(render_host_runtime_dir "${RENDER_DIR}" "${HOST_NAME}")"
  METADATA_FILE="$(render_host_metadata_file "${RENDER_DIR}" "${HOST_NAME}")"
  ENV_FILE="$(render_host_env_file "${RENDER_DIR}" "${HOST_NAME}")"
else
  [ -d "${RUNTIME_DIR}" ] || { echo "Runtime dir not found: ${RUNTIME_DIR}" >&2; exit 1; }
  HOST_RUNTIME_DIR="${RUNTIME_DIR}"
  METADATA_FILE="${HOST_RUNTIME_DIR}/render-metadata.env"
  ENV_FILE="${HOST_RUNTIME_DIR}/.env"
fi

[ -f "${METADATA_FILE}" ] || { echo "Render metadata not found: ${METADATA_FILE}" >&2; exit 1; }
[ -f "${ENV_FILE}" ] || { echo "Runtime env not found: ${ENV_FILE}" >&2; exit 1; }

METADATA_HOST_NAME="$(read_env_value "${METADATA_FILE}" "HOST_NAME")"
if [ -z "${HOST_NAME}" ]; then
  HOST_NAME="${METADATA_HOST_NAME}"
fi
[ -n "${HOST_NAME}" ] || { echo "Host name is required or must be present in render-metadata.env." >&2; exit 1; }
if [ -n "${METADATA_HOST_NAME}" ] && [ "${METADATA_HOST_NAME}" != "${HOST_NAME}" ]; then
  echo "Host name mismatch: ${HOST_NAME} != metadata ${METADATA_HOST_NAME}" >&2
  exit 1
fi

if [ "${TARGET_MODE}" = "render-dir" ] && [ "${EXECUTE}" -eq 1 ] && [ "${ALLOW_RENDER_DIR_EXECUTE}" -ne 1 ]; then
  echo "Refusing to stage operator artifacts into a render bundle." >&2
  echo "Run this on the operator host with --runtime-dir, or pass --allow-render-dir-execute only for local tests." >&2
  exit 1
fi

TARGET_CHARON_DIR="${HOST_RUNTIME_DIR}/.charon"
TARGET_STAGE_ENV="${HOST_RUNTIME_DIR}/charon-artifacts-staging.env"
TARGET_PUBKEYS_FILE="${HOST_RUNTIME_DIR}/validator-pubkeys.txt"
CLUSTER_NAME="$(read_env_value "${METADATA_FILE}" "CLUSTER_NAME")"
validate_named_approval "${APPROVAL_FILE}" "${CLUSTER_NAME}" "${HOST_NAME}" "charon-artifact-stage"

SOURCE_CHARON_DIR="${SOURCE_DIR}"
if [ -d "${SOURCE_DIR}/.charon" ]; then
  SOURCE_CHARON_DIR="${SOURCE_DIR}/.charon"
fi

if [ -z "${CLUSTER_LOCK_FILE}" ] && [ -f "${SOURCE_CHARON_DIR}/cluster-lock.json" ]; then
  CLUSTER_LOCK_FILE="${SOURCE_CHARON_DIR}/cluster-lock.json"
fi
if [ -z "${ENR_FILE}" ] && [ -f "${SOURCE_CHARON_DIR}/charon-enr-private-key" ]; then
  ENR_FILE="${SOURCE_CHARON_DIR}/charon-enr-private-key"
fi
if [ -z "${PUBKEYS_FILE}" ] && [ -f "${SOURCE_DIR}/validator-pubkeys.txt" ]; then
  PUBKEYS_FILE="${SOURCE_DIR}/validator-pubkeys.txt"
fi
if [ -z "${PUBKEYS_FILE}" ] && [ -f "${SOURCE_CHARON_DIR}/validator-pubkeys.txt" ]; then
  PUBKEYS_FILE="${SOURCE_CHARON_DIR}/validator-pubkeys.txt"
fi

SENSITIVE_SOURCE_PATH="$(find "${SOURCE_DIR}" \( \
  -name validator_keys \
  -o -name 'keystore-*.json' \
  -o -iname '*mnemonic*' \
  -o -iname '*seed*' \
  -o -iname '*password*' \
  -o -iname '*keyshare*' \
\) -print -quit)"
if [ -n "${SENSITIVE_SOURCE_PATH}" ] && [ "${ALLOW_SENSITIVE_SOURCE_DIR}" -ne 1 ]; then
  echo "Sensitive source path detected: ${SENSITIVE_SOURCE_PATH}" >&2
  echo "Use a sanitized operator-local source dir containing only cluster-lock.json, charon-enr-private-key, and optional validator-pubkeys.txt." >&2
  exit 1
fi

[ -n "${CLUSTER_LOCK_FILE}" ] || { echo "cluster-lock.json not found under ${SOURCE_DIR}. Pass --cluster-lock-file if needed." >&2; exit 1; }
[ -f "${CLUSTER_LOCK_FILE}" ] || { echo "cluster-lock.json file not found: ${CLUSTER_LOCK_FILE}" >&2; exit 1; }
[ -n "${ENR_FILE}" ] || { echo "charon-enr-private-key not found under ${SOURCE_DIR}. Pass --enr-file if needed." >&2; exit 1; }
[ -f "${ENR_FILE}" ] || { echo "charon-enr-private-key file not found: ${ENR_FILE}" >&2; exit 1; }

WEB3SIGNER_FETCH="$(read_env_value "${ENV_FILE}" "WEB3SIGNER_FETCH" || true)"
[ -n "${WEB3SIGNER_FETCH}" ] || WEB3SIGNER_FETCH="true"

PUBKEY_COUNT=0
PUBKEYS_CSV=""
NORMALIZED_PUBKEYS=""
PUBKEYS_TMP_FILE=""
if [ -n "${PUBKEYS_FILE}" ]; then
  [ -f "${PUBKEYS_FILE}" ] || { echo "validator pubkeys file not found: ${PUBKEYS_FILE}" >&2; exit 1; }
  NORMALIZED_PUBKEYS="$(awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      gsub(/\r/, "", $0)
      gsub(/^[[:space:]]+/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      print
    }
  ' "${PUBKEYS_FILE}")"

  if [ -n "${NORMALIZED_PUBKEYS}" ]; then
    while IFS= read -r pubkey; do
      case "${pubkey}" in
        0x[0-9a-fA-F]*)
          ;;
        *)
          echo "Invalid validator pubkey entry: ${pubkey}" >&2
          exit 1
          ;;
      esac
    done <<EOF
${NORMALIZED_PUBKEYS}
EOF
    PUBKEY_COUNT="$(printf '%s\n' "${NORMALIZED_PUBKEYS}" | awk 'NF {count += 1} END {print count + 0}')"
    PUBKEYS_CSV="$(printf '%s\n' "${NORMALIZED_PUBKEYS}" | awk 'NF { if (out != "") out = out ","; out = out $0 } END { print out }')"
  fi
fi

if [ "${WEB3SIGNER_FETCH}" = "false" ] && [ -z "${PUBKEYS_CSV}" ]; then
  echo "WEB3SIGNER_FETCH=false requires validator pubkeys. Provide --pubkeys-file or source-dir/validator-pubkeys.txt." >&2
  exit 1
fi

TARGET_CLUSTER_LOCK="${TARGET_CHARON_DIR}/cluster-lock.json"
TARGET_ENR_FILE="${TARGET_CHARON_DIR}/charon-enr-private-key"
CONFLICT_COUNT=0

if [ "${FORCE}" -ne 1 ]; then
  for existing_path in "${TARGET_CLUSTER_LOCK}" "${TARGET_ENR_FILE}" "${TARGET_STAGE_ENV}"; do
    if [ -e "${existing_path}" ]; then
      if [ "${EXECUTE}" -eq 1 ]; then
        echo "Target already exists: ${existing_path}. Re-run with --force to replace staged artifacts." >&2
        exit 1
      fi
      CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
    fi
  done
  if [ -n "${PUBKEYS_CSV}" ] && [ -e "${TARGET_PUBKEYS_FILE}" ]; then
    if [ "${EXECUTE}" -eq 1 ]; then
      echo "Target already exists: ${TARGET_PUBKEYS_FILE}. Re-run with --force to replace staged artifacts." >&2
      exit 1
    fi
    CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
  fi
fi

STAGED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
CLUSTER_LOCK_SHA256="$(sha256_file "${CLUSTER_LOCK_FILE}")"
ENR_SHA256="$(sha256_file "${ENR_FILE}")"
PUBKEYS_SHA256=""
if [ -n "${PUBKEYS_CSV}" ]; then
  PUBKEYS_TMP_FILE="$(mktemp "${TMPDIR:-/tmp}/cdvn-pubkeys.XXXXXX")"
  printf '%s\n' "${NORMALIZED_PUBKEYS}" > "${PUBKEYS_TMP_FILE}"
  PUBKEYS_SHA256="$(sha256_file "${PUBKEYS_TMP_FILE}")"
  rm -f "${PUBKEYS_TMP_FILE}"
fi

echo "Stage charon artifacts host: ${HOST_NAME}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Mode: $([ "${EXECUTE}" -eq 1 ] && printf 'execute' || printf 'dry-run')"
echo "Target mode: ${TARGET_MODE}"
echo "Source dir: ${SOURCE_DIR}"
echo "Source charon dir: ${SOURCE_CHARON_DIR}"
echo "Target runtime: ${HOST_RUNTIME_DIR}"
echo "Stage targets:"
echo "- ${CLUSTER_LOCK_FILE} -> ${TARGET_CLUSTER_LOCK}"
echo "- ${ENR_FILE} -> ${TARGET_ENR_FILE}"
if [ -n "${PUBKEYS_CSV}" ]; then
  echo "- ${PUBKEYS_FILE} -> ${TARGET_PUBKEYS_FILE}"
  echo "- WEB3SIGNER_PUBLIC_KEYS updated from ${PUBKEY_COUNT} pubkeys"
fi
if [ "${CONFLICT_COUNT}" -gt 0 ]; then
  echo "Existing staged files detected: ${CONFLICT_COUNT} path(s) would require --force on execute."
fi

if [ "${EXECUTE}" -ne 1 ]; then
  echo "Approval file: ${APPROVAL_FILE}"
  echo "Staging metadata file: ${TARGET_STAGE_ENV}"
  exit 0
fi

mkdir -p "${TARGET_CHARON_DIR}"
install -m 0644 "${CLUSTER_LOCK_FILE}" "${TARGET_CLUSTER_LOCK}"
install -m 0600 "${ENR_FILE}" "${TARGET_ENR_FILE}"

if [ -n "${PUBKEYS_CSV}" ]; then
  printf '%s\n' "${NORMALIZED_PUBKEYS}" > "${TARGET_PUBKEYS_FILE}"
  upsert_env_value "${ENV_FILE}" "WEB3SIGNER_PUBLIC_KEYS" "${PUBKEYS_CSV}"
else
  rm -f "${TARGET_PUBKEYS_FILE}"
  remove_env_value "${ENV_FILE}" "WEB3SIGNER_PUBLIC_KEYS"
fi

APPROVAL_ID="$(read_env_value "${APPROVAL_FILE}" "APPROVAL_ID")"
APPROVED_BY="$(read_env_value "${APPROVAL_FILE}" "APPROVED_BY")"
APPROVED_AT="$(read_env_value "${APPROVAL_FILE}" "APPROVED_AT")"

cat > "${TARGET_STAGE_ENV}" <<EOF
STAGED_AT=${STAGED_AT}
APPROVAL_ID=${APPROVAL_ID}
APPROVAL_POLICY=charon-artifact-stage
APPROVED_BY=${APPROVED_BY}
APPROVED_AT=${APPROVED_AT}
CLUSTER_NAME=${CLUSTER_NAME}
HOST_NAME=${HOST_NAME}
SOURCE_DIR=${SOURCE_DIR}
SOURCE_CHARON_DIR=${SOURCE_CHARON_DIR}
CLUSTER_LOCK_FILE=${CLUSTER_LOCK_FILE}
CLUSTER_LOCK_SHA256=${CLUSTER_LOCK_SHA256}
ENR_FILE=${ENR_FILE}
ENR_SHA256=${ENR_SHA256}
PUBKEYS_FILE=${PUBKEYS_FILE}
PUBKEYS_SHA256=${PUBKEYS_SHA256}
PUBKEY_COUNT=${PUBKEY_COUNT}
TARGET_MODE=${TARGET_MODE}
EOF

echo "Staged charon artifacts into ${TARGET_CHARON_DIR}"
