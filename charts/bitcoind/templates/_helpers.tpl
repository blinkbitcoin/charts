{{/* vim: set filetype=mustache: */}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "bitcoind.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bitcoind.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bitcoind.labels" -}}
helm.sh/chart: {{ include "bitcoind.chart" . }}
{{ include "bitcoind.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bitcoind.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "bitcoind.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "bitcoind.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{- define "rpcpassword" -}}

{{- $secret := (lookup "v1" "Secret" .Release.Namespace (printf "%s-rpcpassword" (include "bitcoind.fullname" .))) -}}
{{- if $secret -}}
{{/*
   Reusing current password since secret exists
*/}}
{{-  $secret.data.password | b64dec -}}
{{- else -}}
{{/*
    Generate new password
*/}}
{{- randAlpha 24 -}}
{{- end -}}
{{- end -}}

{{/*
Shared shell helpers for descriptor-import sidecars.
*/}}
{{- define "bitcoind.walletWaitScript" -}}
bitcoin_cli() {
  bitcoin-cli -conf=/data/.bitcoin/bitcoin.conf "$@"
}

lock_stale_seconds=600
lock_dir="/wallet-load-lock/wallet-load.lock"
lock_holder_file="${lock_dir}/holder"
lock_holder_missing_since=0
wallet_load_lock_acquired=0
wallet_load_lock_heartbeat_pid=0

release_wallet_load_lock() {
  if [ "${wallet_load_lock_acquired}" = "1" ]; then
    if [ "${wallet_load_lock_heartbeat_pid}" != "0" ]; then
      kill "${wallet_load_lock_heartbeat_pid}" 2>/dev/null || true
      wait "${wallet_load_lock_heartbeat_pid}" 2>/dev/null || true
      wallet_load_lock_heartbeat_pid=0
    fi
    rm -f "${lock_holder_file}" "${lock_dir}"/holder.* 2>/dev/null || true
    rmdir "${lock_dir}" 2>/dev/null || true
    wallet_load_lock_acquired=0
  fi
}

terminate_wallet_wait() {
  release_wallet_load_lock
  echo shutting down
  exit 0
}

wallet_load_lock_is_stale() {
  now=$(date +%s)
  if [ -r "${lock_holder_file}" ]; then
    lock_started_at=$(cut -d' ' -f1 <"${lock_holder_file}" 2>/dev/null || true)
    case "${lock_started_at}" in
      ''|*[!0-9]*)
        rm -f "${lock_holder_file}" 2>/dev/null || true
        if [ "${lock_holder_missing_since}" = "0" ]; then
          lock_holder_missing_since="${now}"
        fi
        lock_started_at="${lock_holder_missing_since}"
        ;;
      *)
        lock_holder_missing_since=0
        ;;
    esac
  else
    if [ "${lock_holder_missing_since}" = "0" ]; then
      lock_holder_missing_since="${now}"
    fi
    lock_started_at="${lock_holder_missing_since}"
  fi

  [ $((now - lock_started_at)) -ge "${lock_stale_seconds}" ]
}

write_wallet_load_lock_holder() {
  lock_holder_tmp="${lock_holder_file}.$$"
  if printf '%s %s\n' "$(date +%s)" "$$" >"${lock_holder_tmp}"; then
    mv "${lock_holder_tmp}" "${lock_holder_file}" 2>/dev/null || rm -f "${lock_holder_tmp}"
  else
    rm -f "${lock_holder_tmp}" 2>/dev/null || true
  fi
}

start_wallet_load_lock_heartbeat() {
  # Keep legitimate long wallet load/create calls from being declared stale.
  (
    while [ -d "${lock_dir}" ]; do
      write_wallet_load_lock_holder
      sleep 60
    done
  ) &
  wallet_load_lock_heartbeat_pid="$!"
}

remove_stale_wallet_load_lock() {
  wallet_to_check="$1"
  if wallet_load_lock_is_stale; then
    echo "# Removing stale wallet load lock for ${wallet_to_check}"
    rm -f "${lock_holder_file}" "${lock_dir}"/holder.* 2>/dev/null || true
    rmdir "${lock_dir}" 2>/dev/null || true
    lock_holder_missing_since=0
  fi
}

wallet_exists() {
  wallet_to_find="$1"
  if wallet_dir_json=$(bitcoin_cli listwalletdir); then
    echo "${wallet_dir_json}" | grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${wallet_to_find}\""
    return $?
  fi

  return 2
}

wait_for_wallet() {
  wallet_name="$1"
  retry_seconds=30
  lock_holder_missing_since=0

  while true; do
    while ! mkdir "${lock_dir}" 2>/dev/null; do
      remove_stale_wallet_load_lock "${wallet_name}"
      echo "# Another wallet load is in progress; waiting to check ${wallet_name}"
      sleep 5
    done
    wallet_load_lock_acquired=1
    lock_holder_missing_since=0
    start_wallet_load_lock_heartbeat

    if bitcoin_cli listwallets | grep -q "\"${wallet_name}\""; then
      echo "# Wallet ${wallet_name} is loaded"
      release_wallet_load_lock
      return 0
    fi

    echo "# Loading the ${wallet_name} wallet"
    if loadwallet_output=$(bitcoin_cli loadwallet "${wallet_name}" 2>&1); then
      echo "# Loaded the ${wallet_name} wallet"
      release_wallet_load_lock
      return 0
    fi
    echo "# loadwallet ${wallet_name} failed: ${loadwallet_output}"

    wallet_exists "${wallet_name}"
    wallet_exists_status="$?"
    case "${wallet_exists_status}" in
      0)
        echo "# Wallet ${wallet_name} exists but is not ready to load"
        ;;
      1)
        echo "# Creating the ${wallet_name} wallet"
        if bitcoin_cli createwallet "${wallet_name}"; then
          echo "# Created the ${wallet_name} wallet"
          release_wallet_load_lock
          return 0
        fi
        ;;
      *)
        echo "# Could not list wallet directory for ${wallet_name}; will retry"
        ;;
    esac

    release_wallet_load_lock
    echo "# Wallet ${wallet_name} is not ready; retrying in ${retry_seconds}s"
    sleep "${retry_seconds}"
  done
}
{{- end -}}
