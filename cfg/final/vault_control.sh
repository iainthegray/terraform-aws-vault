#!/bin/bash
# This script is used to do the final config of vault and consul as per the
# deployment guide: https://www.vaultproject.io/guides/operations/deployment-guide.html

set -euf -o pipefail

TMP_DIR="/tmp/ins"

function print_usage {
  echo
  echo "Usage: vault-control.sh [OPTIONS]"
  echo "Options:"
  echo
  echo -e "  --consul-ips\t\t A comma separated string in \" no spaces of consul server IPs. Required"
  echo
  echo -e "  --vault-ips\t\t A comma separated string in \" no spaces of vault server IPs. Required"
  echo
  echo -e "  --action\t\t One of start or stop. Required"
  echo
}

function log {
  local -r level="$1"
  local -r func="$2"
  local -r message="$3"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [${func}] ${message}"
}

function assert_not_empty {
  local func="assert_not_empty"
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log "ERROR" "$func" "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function consul_action {
  local func="consul_action"
  local -r action="$1"
  local -r ip="$2"
  local -r token="$3"
  local alive=0
  case "$action" in
    "start")
      log "INFO" "${func}" "Starting consul server on $ip"
      ssh -oStrictHostKeyChecking=no $ip sudo systemctl start consul
      ;;
    "stop")
      log "INFO" "${func}" "Stopping consul server on $ip"
      ssh -oStrictHostKeyChecking=no $ip sudo systemctl stop consul
      ;;
    *)
      log "ERROR" $func "Unrecognized argument: $action"
      exit
    esac
}
function vault_action {
  local func="vault_action"
  local -r action="$1"
  local -r ip="$2"
  local -r token="$3"
  local alive=0
  case "$action" in
    "start")
      log "INFO" "${func}" "Starting vault server on $ip"
      ssh -oStrictHostKeyChecking=no $ip sudo systemctl start vault
      ;;
    "stop")
      log "INFO" "${func}" "Stopping vault server on $ip"
      ssh -oStrictHostKeyChecking=no $ip sudo systemctl stop vault
      ;;
    *)
      log "ERROR" $func "Unrecognized argument: $action"
      exit
    esac
}

function run_it {
  local func="run_it"
  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --help)
        print_usage
        exit
        ;;
      --consul-ips)
        CONSUL_IPS="$2"
        shift
        ;;
      --vault-ips)
        VAULT_IPS="$2"
        shift
        ;;
      --action)
        action="$2"
        shift
        ;;
      *)
        log "ERROR" $func "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--consul-ips" "$CONSUL_IPS"
  assert_not_empty "--vault-ips" "$VAULT_IPS"
  assert_not_empty "--action" "$action"

  if [[ "$action" == "start" ]]
  then
    for ip in `echo $CONSUL_IPS $VAULT_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
    do
      consul_action "$action" "$ip"
    done
    for ip in `echo $VAULT_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
    do
      vault_action "$action" "$ip"
    done
  elif [[ "$action" == "stop" ]]
  then
    for ip in `echo $VAULT_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
    do
      vault_action "$action" "$ip"
    done
    for ip in `echo $CONSUL_IPS $VAULT_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
    do
      consul_action "$action" "$ip"
    done
  else
    log "ERROR" "must supply one of start|stop"
    exit 1
  fi
}

run_it "$@"
