#!/usr/bin/env bash

SCRIPT_LIB_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(CDPATH= cd -- "${SCRIPT_LIB_DIR}/.." && pwd)"
BASELINE_DIR="${INFRA_DIR}/baseline"
UPSTREAM_DIR="${BASELINE_DIR}/upstream"
VERSION_FILE="${BASELINE_DIR}/VERSION"
OVERLAYS_DIR="${INFRA_DIR}/overlays"

strip_quotes() {
  local value="${1:-}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

sanitize_name() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

csv_normalize() {
  printf '%s' "${1:-}" | tr -d ' '
}

csv_contains() {
  local csv normalized target
  csv="$(csv_normalize "${1:-}")"
  target="${2:-}"
  IFS=',' read -r -a _csv_items <<<"$csv"
  for normalized in "${_csv_items[@]}"; do
    if [ "$normalized" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

escape_sed_replacement() {
  printf '%s' "${1:-}" | sed -e 's/[|&\\]/\\&/g'
}

shell_quote() {
  printf '%q' "${1:-}"
}

sha256_file() {
  local file="$1"

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi

  echo "No SHA-256 tool found (expected shasum or sha256sum)." >&2
  exit 1
}

read_yaml_scalar() {
  local file="$1"
  local key="$2"
  local raw
  raw="$(sed -n "s/^  ${key}:[[:space:]]*//p" "$file" | head -n 1)"
  strip_quotes "$raw"
}

read_env_value() {
  local file="$1"
  local key="$2"
  if [ ! -f "$file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$file" | tail -n 1
}

upsert_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp

  tmp="$(mktemp "${TMPDIR:-/tmp}/cdvn-env.XXXXXX")"
  if [ -f "$file" ]; then
    awk -v key="$key" -v value="$value" '
      BEGIN { written = 0 }
      index($0, key "=") == 1 {
        if (written == 0) {
          print key "=" value
          written = 1
        }
        next
      }
      { print }
      END {
        if (written == 0) {
          print key "=" value
        }
      }
    ' "$file" > "$tmp"
  else
    printf '%s=%s\n' "$key" "$value" > "$tmp"
  fi
  mv "$tmp" "$file"
}

remove_env_value() {
  local file="$1"
  local key="$2"
  local tmp

  [ -f "$file" ] || return 0

  tmp="$(mktemp "${TMPDIR:-/tmp}/cdvn-env.XXXXXX")"
  awk -v key="$key" '
    index($0, key "=") == 1 { next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

apply_env_defaults() {
  local env_file="$1"
  local defaults_file="$2"
  local line key value

  [ -f "$defaults_file" ] || return 0

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ""|\#*)
        continue
        ;;
    esac

    key="${line%%=*}"
    value="${line#*=}"
    upsert_env_value "$env_file" "$key" "$value"
  done < "$defaults_file"
}

render_template() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"
  sed \
    -e "s|__CLUSTER_NAME__|$(escape_sed_replacement "${RUNTIME_CLUSTER_NAME:-}")|g" \
    -e "s|__CLUSTER_PEER__|$(escape_sed_replacement "${RUNTIME_CLUSTER_PEER:-}")|g" \
    -e "s|__HOST_NAME__|$(escape_sed_replacement "${RUNTIME_HOST_NAME:-}")|g" \
    -e "s|__VC_METRICS_TARGET__|$(escape_sed_replacement "${RUNTIME_VC_METRICS_TARGET:-vc-lodestar:5064}")|g" \
    -e "s|__WEB3SIGNER_METRICS_TARGET__|$(escape_sed_replacement "${RUNTIME_WEB3SIGNER_METRICS_TARGET:-host.docker.internal:9000}")|g" \
    "$src" > "$dst"
}

require_baseline() {
  if [ ! -f "${VERSION_FILE}" ]; then
    echo "Missing pinned baseline metadata: ${VERSION_FILE}" >&2
    exit 1
  fi

  if [ ! -d "${UPSTREAM_DIR}" ]; then
    echo "Missing upstream baseline mirror: ${UPSTREAM_DIR}" >&2
    exit 1
  fi
}

get_pinned_baseline_ref() {
  read_env_value "${VERSION_FILE}" "UPSTREAM_REF"
}

load_cluster_config() {
  local file="$1"

  CLUSTER_NAME="$(read_yaml_scalar "$file" "name")"
  CLUSTER_NETWORK="$(read_yaml_scalar "$file" "network")"
  CLUSTER_BASELINE_VERSION="$(read_yaml_scalar "$file" "baselineVersion")"
  CLUSTER_OVERLAY_PROFILES="$(read_yaml_scalar "$file" "overlayProfiles")"
  if [ -z "${CLUSTER_OVERLAY_PROFILES}" ]; then
    CLUSTER_OVERLAY_PROFILES="$(read_yaml_scalar "$file" "overlayProfile")"
  fi
  CLUSTER_THRESHOLD="$(read_yaml_scalar "$file" "threshold")"
  CLUSTER_OPERATOR_COUNT="$(read_yaml_scalar "$file" "operatorCount")"
  CLUSTER_COMPOSE_ENV_SAMPLE="$(read_yaml_scalar "$file" "composeEnvSample")"
  CLUSTER_SIGNER_MODE="$(read_yaml_scalar "$file" "signerMode")"
  CLUSTER_RELAY_MODE="$(read_yaml_scalar "$file" "relayMode")"
  CLUSTER_MONITORING_NAME="$(read_yaml_scalar "$file" "monitoringClusterName")"
  CLUSTER_SERVICE_OWNER="$(read_yaml_scalar "$file" "serviceOwner")"
  CLUSTER_WEB3SIGNER_URL="$(read_yaml_scalar "$file" "web3signerUrl")"
  CLUSTER_WEB3SIGNER_METRICS_TARGET="$(read_yaml_scalar "$file" "web3signerMetricsTarget")"
  CLUSTER_WEB3SIGNER_FETCH="$(read_yaml_scalar "$file" "web3signerFetch")"
  CLUSTER_WEB3SIGNER_FETCH_INTERVAL_MS="$(read_yaml_scalar "$file" "web3signerFetchIntervalMs")"
  CLUSTER_FEE_RECIPIENT_ADDRESS="$(read_yaml_scalar "$file" "feeRecipientAddress")"
  CLUSTER_HEALTH_SYNC_URL="$(read_yaml_scalar "$file" "healthSyncUrl")"
  CLUSTER_DEPLOYMENT_ROOT="$(read_yaml_scalar "$file" "deploymentRoot")"
  CLUSTER_APPROVAL_POLICY="$(read_yaml_scalar "$file" "approvalPolicy")"

  [ -n "${CLUSTER_SERVICE_OWNER}" ] || CLUSTER_SERVICE_OWNER="${CLUSTER_NAME}"
  [ -n "${CLUSTER_MONITORING_NAME}" ] || CLUSTER_MONITORING_NAME="${CLUSTER_NAME}"
  [ -n "${CLUSTER_WEB3SIGNER_FETCH}" ] || CLUSTER_WEB3SIGNER_FETCH="true"
  [ -n "${CLUSTER_WEB3SIGNER_FETCH_INTERVAL_MS}" ] || CLUSTER_WEB3SIGNER_FETCH_INTERVAL_MS="384000"
}

HOST_COUNT=0
HOST_NAMES=()
HOST_ADDRESSES=()
HOST_ROLES=()
HOST_PROFILES=()
HOST_REGIONS=()
HOST_NICKNAMES=()
HOST_EXTERNAL_HOSTNAMES=()
HOST_MONITORING_PEERS=()
HOST_GRAFANA_PORTS=()
HOST_PROMETHEUS_PORTS=()
HOST_SSH_USERS=()
HOST_DEPLOYMENT_PATHS=()

_commit_host_record() {
  [ -n "${_HOST_NAME:-}" ] || return 0

  HOST_NAMES[$HOST_COUNT]="${_HOST_NAME:-}"
  HOST_ADDRESSES[$HOST_COUNT]="${_HOST_ADDRESS:-}"
  HOST_ROLES[$HOST_COUNT]="${_HOST_ROLE:-}"
  HOST_PROFILES[$HOST_COUNT]="${_HOST_PROFILE:-}"
  HOST_REGIONS[$HOST_COUNT]="${_HOST_REGION:-}"
  HOST_NICKNAMES[$HOST_COUNT]="${_HOST_NICKNAME:-}"
  HOST_EXTERNAL_HOSTNAMES[$HOST_COUNT]="${_HOST_EXTERNAL_HOSTNAME:-}"
  HOST_MONITORING_PEERS[$HOST_COUNT]="${_HOST_MONITORING_PEER:-}"
  HOST_GRAFANA_PORTS[$HOST_COUNT]="${_HOST_GRAFANA_PORT:-}"
  HOST_PROMETHEUS_PORTS[$HOST_COUNT]="${_HOST_PROMETHEUS_PORT:-}"
  HOST_SSH_USERS[$HOST_COUNT]="${_HOST_SSH_USER:-}"
  HOST_DEPLOYMENT_PATHS[$HOST_COUNT]="${_HOST_DEPLOYMENT_PATH:-}"
  HOST_COUNT=$((HOST_COUNT + 1))
}

_assign_host_field() {
  local key="$1"
  local value
  value="$(strip_quotes "${2:-}")"

  case "$key" in
    name) _HOST_NAME="$value" ;;
    address) _HOST_ADDRESS="$value" ;;
    role) _HOST_ROLE="$value" ;;
    profile) _HOST_PROFILE="$value" ;;
    region) _HOST_REGION="$value" ;;
    nickname) _HOST_NICKNAME="$value" ;;
    charonExternalHostname) _HOST_EXTERNAL_HOSTNAME="$value" ;;
    monitoringPeer) _HOST_MONITORING_PEER="$value" ;;
    grafanaPort) _HOST_GRAFANA_PORT="$value" ;;
    prometheusPort) _HOST_PROMETHEUS_PORT="$value" ;;
    sshUser) _HOST_SSH_USER="$value" ;;
    deploymentPath) _HOST_DEPLOYMENT_PATH="$value" ;;
  esac
}

parse_hosts_file() {
  local file="$1"
  local line body key value

  HOST_COUNT=0
  HOST_NAMES=()
  HOST_ADDRESSES=()
  HOST_ROLES=()
  HOST_PROFILES=()
  HOST_REGIONS=()
  HOST_NICKNAMES=()
  HOST_EXTERNAL_HOSTNAMES=()
  HOST_MONITORING_PEERS=()
  HOST_GRAFANA_PORTS=()
  HOST_PROMETHEUS_PORTS=()
  HOST_SSH_USERS=()
  HOST_DEPLOYMENT_PATHS=()

  _HOST_NAME=""
  _HOST_ADDRESS=""
  _HOST_ROLE=""
  _HOST_PROFILE=""
  _HOST_REGION=""
  _HOST_NICKNAME=""
  _HOST_EXTERNAL_HOSTNAME=""
  _HOST_MONITORING_PEER=""
  _HOST_GRAFANA_PORT=""
  _HOST_PROMETHEUS_PORT=""
  _HOST_SSH_USER=""
  _HOST_DEPLOYMENT_PATH=""

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "  - "*)
        _commit_host_record
        _HOST_NAME=""
        _HOST_ADDRESS=""
        _HOST_ROLE=""
        _HOST_PROFILE=""
        _HOST_REGION=""
        _HOST_NICKNAME=""
        _HOST_EXTERNAL_HOSTNAME=""
        _HOST_MONITORING_PEER=""
        _HOST_GRAFANA_PORT=""
        _HOST_PROMETHEUS_PORT=""
        _HOST_SSH_USER=""
        _HOST_DEPLOYMENT_PATH=""

        body="${line#  - }"
        key="${body%%:*}"
        value="${body#*: }"
        _assign_host_field "$key" "$value"
        ;;
      "    "*)
        body="${line#    }"
        key="${body%%:*}"
        value="${body#*: }"
        _assign_host_field "$key" "$value"
        ;;
    esac
  done < "$file"

  _commit_host_record
}

find_host_index() {
  local host_name="$1"
  local index=0
  while [ "$index" -lt "$HOST_COUNT" ]; do
    if [ "${HOST_NAMES[$index]}" = "$host_name" ]; then
      printf '%s' "$index"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

load_host_record() {
  local index="$1"
  HOST_NAME="${HOST_NAMES[$index]}"
  HOST_ADDRESS="${HOST_ADDRESSES[$index]}"
  HOST_ROLE="${HOST_ROLES[$index]}"
  HOST_PROFILE="${HOST_PROFILES[$index]}"
  HOST_REGION="${HOST_REGIONS[$index]}"
  HOST_NICKNAME="${HOST_NICKNAMES[$index]}"
  HOST_EXTERNAL_HOSTNAME="${HOST_EXTERNAL_HOSTNAMES[$index]}"
  HOST_MONITORING_PEER="${HOST_MONITORING_PEERS[$index]}"
  HOST_GRAFANA_PORT="${HOST_GRAFANA_PORTS[$index]}"
  HOST_PROMETHEUS_PORT="${HOST_PROMETHEUS_PORTS[$index]}"
  HOST_SSH_USER="${HOST_SSH_USERS[$index]}"
  HOST_DEPLOYMENT_PATH="${HOST_DEPLOYMENT_PATHS[$index]}"
}

load_host_config() {
  local file="$1"

  HOST_NAME="$(read_yaml_scalar "$file" "name")"
  HOST_ADDRESS="$(read_yaml_scalar "$file" "address")"
  HOST_ROLE="$(read_yaml_scalar "$file" "role")"
  HOST_PROFILE="$(read_yaml_scalar "$file" "profile")"
  HOST_REGION="$(read_yaml_scalar "$file" "region")"
  HOST_NICKNAME="$(read_yaml_scalar "$file" "nickname")"
  HOST_EXTERNAL_HOSTNAME="$(read_yaml_scalar "$file" "charonExternalHostname")"
  HOST_MONITORING_PEER="$(read_yaml_scalar "$file" "monitoringPeer")"
  HOST_GRAFANA_PORT="$(read_yaml_scalar "$file" "grafanaPort")"
  HOST_PROMETHEUS_PORT="$(read_yaml_scalar "$file" "prometheusPort")"
  HOST_SSH_USER="$(read_yaml_scalar "$file" "sshUser")"
  HOST_DEPLOYMENT_PATH="$(read_yaml_scalar "$file" "deploymentPath")"

  [ -n "${HOST_NAME}" ] || {
    echo "Host file must include host.name using the example two-space YAML indentation: ${file}" >&2
    exit 1
  }
}

render_host_runtime_dir() {
  local render_dir="$1"
  local host_name="$2"
  printf '%s/hosts/%s/runtime' "${render_dir}" "${host_name}"
}

render_host_metadata_file() {
  local render_dir="$1"
  local host_name="$2"
  printf '%s/render-metadata.env' "$(render_host_runtime_dir "${render_dir}" "${host_name}")"
}

render_host_env_file() {
  local render_dir="$1"
  local host_name="$2"
  printf '%s/.env' "$(render_host_runtime_dir "${render_dir}" "${host_name}")"
}

runtime_metadata_file() {
  local runtime_dir="$1"
  printf '%s/render-metadata.env' "${runtime_dir}"
}

runtime_env_file() {
  local runtime_dir="$1"
  printf '%s/.env' "${runtime_dir}"
}

resolve_runtime_dir_arg() {
  local render_or_runtime_dir="$1"
  local host_name="${2:-}"

  if [ -d "${render_or_runtime_dir}/hosts" ]; then
    [ -n "${host_name}" ] || {
      echo "--host-name is required when --render-dir points to a cluster bundle." >&2
      return 1
    }
    require_rendered_host "${render_or_runtime_dir}" "${host_name}"
    render_host_runtime_dir "${render_or_runtime_dir}" "${host_name}"
    return 0
  fi

  if [ ! -d "${render_or_runtime_dir}" ]; then
    echo "Runtime dir not found: ${render_or_runtime_dir}" >&2
    return 1
  fi

  if [ ! -f "${render_or_runtime_dir}/render-metadata.env" ]; then
    echo "Render metadata not found: ${render_or_runtime_dir}/render-metadata.env" >&2
    return 1
  fi

  printf '%s' "${render_or_runtime_dir}"
}

resolve_host_name_arg() {
  local runtime_dir="$1"
  local explicit_host_name="${2:-}"
  local metadata_host_name

  metadata_host_name="$(read_env_value "${runtime_dir}/render-metadata.env" "HOST_NAME")"
  if [ -n "${explicit_host_name}" ] && [ -n "${metadata_host_name}" ] && [ "${explicit_host_name}" != "${metadata_host_name}" ]; then
    echo "Host name mismatch: ${explicit_host_name} != metadata ${metadata_host_name}" >&2
    return 1
  fi

  if [ -n "${explicit_host_name}" ]; then
    printf '%s' "${explicit_host_name}"
    return 0
  fi

  if [ -n "${metadata_host_name}" ]; then
    printf '%s' "${metadata_host_name}"
    return 0
  fi

  echo "Host name is required or must be present in render-metadata.env." >&2
  return 1
}

require_rendered_host() {
  local render_dir="$1"
  local host_name="$2"
  local runtime_dir metadata_file

  runtime_dir="$(render_host_runtime_dir "${render_dir}" "${host_name}")"
  metadata_file="$(render_host_metadata_file "${render_dir}" "${host_name}")"

  if [ ! -d "${runtime_dir}" ]; then
    echo "Rendered host runtime not found: ${runtime_dir}" >&2
    exit 1
  fi

  if [ ! -f "${metadata_file}" ]; then
    echo "Render metadata not found: ${metadata_file}" >&2
    exit 1
  fi
}

validate_rollout_approval() {
  local approval_file="$1"
  local metadata_file="$2"
  local host_name="$3"
  local expected_cluster_name expected_policy

  [ -f "${approval_file}" ] || { echo "Approval file not found: ${approval_file}" >&2; exit 1; }

  expected_cluster_name="$(read_env_value "${metadata_file}" "CLUSTER_NAME")"
  expected_policy="$(read_env_value "${metadata_file}" "APPROVAL_POLICY")"

  validate_named_approval "${approval_file}" "${expected_cluster_name}" "${host_name}" "${expected_policy}"
}

validate_named_approval() {
  local approval_file="$1"
  local expected_cluster_name="$2"
  local expected_host_name="$3"
  local expected_policy="$4"
  local approval_status approval_policy approval_cluster_name approval_host_name

  [ -f "${approval_file}" ] || { echo "Approval file not found: ${approval_file}" >&2; exit 1; }

  approval_status="$(read_env_value "${approval_file}" "APPROVAL_STATUS")"
  approval_policy="$(read_env_value "${approval_file}" "APPROVAL_POLICY")"
  approval_cluster_name="$(read_env_value "${approval_file}" "CLUSTER_NAME")"
  approval_host_name="$(read_env_value "${approval_file}" "HOST_NAME")"

  if [ "${approval_status}" != "APPROVED" ]; then
    echo "Approval status must be APPROVED." >&2
    exit 1
  fi

  if [ "${approval_policy}" != "${expected_policy}" ]; then
    echo "Approval policy mismatch: ${approval_policy} != ${expected_policy}" >&2
    exit 1
  fi

  if [ "${approval_cluster_name}" != "${expected_cluster_name}" ]; then
    echo "Approval cluster mismatch: ${approval_cluster_name} != ${expected_cluster_name}" >&2
    exit 1
  fi

  if [ "${approval_host_name}" != "${expected_host_name}" ]; then
    echo "Approval host mismatch: ${approval_host_name} != ${expected_host_name}" >&2
    exit 1
  fi
}

resolve_ssh_target_from_metadata() {
  local metadata_file="$1"
  local explicit_target="${2:-}"
  local metadata_target ssh_user host_address

  if [ -n "${explicit_target}" ]; then
    printf '%s' "${explicit_target}"
    return 0
  fi

  metadata_target="$(read_env_value "${metadata_file}" "SSH_TARGET")"
  if [ -n "${metadata_target}" ]; then
    printf '%s' "${metadata_target}"
    return 0
  fi

  ssh_user="$(read_env_value "${metadata_file}" "SSH_USER")"
  host_address="$(read_env_value "${metadata_file}" "HOST_ADDRESS")"

  if [ -n "${ssh_user}" ] && [ -n "${host_address}" ]; then
    printf '%s@%s' "${ssh_user}" "${host_address}"
    return 0
  fi

  return 1
}
