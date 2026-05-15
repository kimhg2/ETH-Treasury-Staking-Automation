#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage:
  verify.sh --render-dir <bundle-or-runtime-path> [--host-name <name>]

Examples:
  ./verify.sh --render-dir /tmp/cdvn-bundle
  ./verify.sh --render-dir /tmp/cdvn-bundle --host-name operator-1
  ./verify.sh --render-dir /opt/obol/cluster-a
EOF
}

RENDER_DIR=""
HOST_NAME_FILTER=""
FAILURES=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --render-dir)
      RENDER_DIR="${2:-}"
      shift 2
      ;;
    --host-name)
      HOST_NAME_FILTER="${2:-}"
      shift 2
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
require_baseline
PINNED_BASELINE_REF="$(get_pinned_baseline_ref)"

verify_runtime_dir() {
  local runtime_dir="$1"
  local env_file="${runtime_dir}/.env"
  local metadata_file="${runtime_dir}/render-metadata.env"
  local override_file="${runtime_dir}/docker-compose.override.yml"
  local overlay_profiles baseline_ref vc_profile charon_dir stage_env web3signer_fetch

  if [ ! -f "${env_file}" ]; then
    echo "Missing env file: ${env_file}" >&2
    FAILURES=$((FAILURES + 1))
    return
  fi

  if [ ! -f "${metadata_file}" ]; then
    echo "Missing render metadata: ${metadata_file}" >&2
    FAILURES=$((FAILURES + 1))
    return
  fi

  if [ ! -f "${override_file}" ]; then
    echo "Missing generated compose override: ${override_file}" >&2
    FAILURES=$((FAILURES + 1))
    return
  fi

  if [ -f "${runtime_dir}/jwt/jwt.hex" ]; then
    echo "Runtime contains jwt/jwt.hex and should not: ${runtime_dir}" >&2
    FAILURES=$((FAILURES + 1))
  fi

  baseline_ref="$(read_env_value "${env_file}" "CDVN_BASELINE_VERSION")"
  if [ "${baseline_ref}" != "${PINNED_BASELINE_REF}" ]; then
    echo "Baseline mismatch in ${runtime_dir}: ${baseline_ref} != ${PINNED_BASELINE_REF}" >&2
    FAILURES=$((FAILURES + 1))
  fi

  overlay_profiles="$(read_env_value "${env_file}" "CDVN_OVERLAY_PROFILES")"
  vc_profile="$(read_env_value "${env_file}" "VC")"
  charon_dir="${runtime_dir}/.charon"
  stage_env="${runtime_dir}/charon-artifacts-staging.env"
  web3signer_fetch="$(read_env_value "${env_file}" "WEB3SIGNER_FETCH")"
  [ -n "${web3signer_fetch}" ] || web3signer_fetch="true"

  if csv_contains "${overlay_profiles}" "web3signer"; then
    if [ "${vc_profile}" != "vc-lodestar" ]; then
      echo "web3signer overlay expects VC=vc-lodestar in ${runtime_dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if ! grep -q -- '--externalSigner.url=' "${runtime_dir}/lodestar/run.sh"; then
      echo "web3signer overlay did not render the Lodestar external signer entrypoint in ${runtime_dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if ! grep -q '^WEB3SIGNER_URL=' "${env_file}"; then
      echo "WEB3SIGNER_URL missing in ${env_file}" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ "${web3signer_fetch}" = "false" ] && [ -f "${stage_env}" ] && ! grep -q '^WEB3SIGNER_PUBLIC_KEYS=' "${env_file}"; then
      echo "WEB3SIGNER_PUBLIC_KEYS missing in ${env_file} while WEB3SIGNER_FETCH=false" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ -d "${charon_dir}/validator_keys" ]; then
      echo "web3signer overlay runtime must not stage .charon/validator_keys in ${runtime_dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi

  if csv_contains "${overlay_profiles}" "observability"; then
    if ! grep -q 'cadvisor:' "${override_file}"; then
      echo "observability overlay did not add cadvisor in ${override_file}" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if ! grep -q 'web3signer' "${runtime_dir}/prometheus/prometheus.yml.example"; then
      echo "observability overlay did not render Web3Signer scrape config in ${runtime_dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if grep -q '\${' "${runtime_dir}/prometheus/prometheus.yml.example"; then
      echo "observability overlay left unresolved template vars in ${runtime_dir}/prometheus/prometheus.yml.example" >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi

  if [ -f "${stage_env}" ]; then
    if [ ! -f "${charon_dir}/cluster-lock.json" ]; then
      echo "charon artifact staging metadata exists but .charon/cluster-lock.json is missing in ${runtime_dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
    if [ ! -f "${charon_dir}/charon-enr-private-key" ]; then
      echo "charon artifact staging metadata exists but .charon/charon-enr-private-key is missing in ${runtime_dir}" >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi

  echo "Verified ${runtime_dir}"
}

if [ -d "${RENDER_DIR}/hosts" ]; then
  if [ -n "${HOST_NAME_FILTER}" ]; then
    verify_runtime_dir "${RENDER_DIR}/hosts/${HOST_NAME_FILTER}/runtime"
  else
    for host_dir in "${RENDER_DIR}"/hosts/*; do
      [ -d "${host_dir}" ] || continue
      verify_runtime_dir "${host_dir}/runtime"
    done
  fi
else
  verify_runtime_dir "${RENDER_DIR}"
fi

if [ "${FAILURES}" -ne 0 ]; then
  echo "Verification failed with ${FAILURES} issue(s)." >&2
  exit 1
fi

echo "Render verification passed."
