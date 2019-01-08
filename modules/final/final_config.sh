#!/bin/bash
# This script is used to do the final config of vault and consul as per the
# deployment guide: https://www.vaultproject.io/guides/operations/deployment-guide.html

local -r TMP_DIR="/tmp/ins"

function print_usage {
  echo
  echo "Usage: final_config.sh [OPTIONS]"
  echo "Options:"
  echo
  echo -e "  --consul-ips\t\t A comma separated string in \" no spaces of consul server IPs."
  echo
  echo -e "  --vault-ips\t\t A comma separated string in \" no spaces of vault server IPs."
  echo
  echo "This script can be used to install Consul as a backend to Vault. It has been tested with Ubuntu 18.04 and Centos 7."
  echo
}

function log {
  local -r level="$1"
  local -r func="$2"
  local -r message="$3"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [${func}] ${message}"
}

function consul_action {
  local func="consul_cluster_action"
  local -r action="$1"
  local -r ip="$2"
  local -r token="$3"
  local alive=0
  case "$action" in
    "start")
      log "INFO" "${func}" "Starting consul server on $ip"
      ssh -oStrictHostKeyChecking=no $ip sudo systemctl start consul
      sleep 3
      alive=`ssh $ip CONSUL_HTTP_TOKEN="$token" consul members -status=alive | grep -v "^Node" | wc -l`
      log "INFO" "${func}" "$alive consul members"
      ;;
    "stop")
      log "INFO" "${func}" "Stopping consul server on $ip"
      ssh -oStrictHostKeyChecking=no $ip sudo systemctl stop consul
      sleep 3
      alive=`ssh $ip CONSUL_HTTP_TOKEN="$token" consul members -status=alive | grep -v "^Node" | wc -l`
      log "INFO" "${func}" "$alive consul members"
      ;;
    *)
      log "ERROR" $func "Unrecognized argument: $action"
      exit
    esac
    echo $alive
}

function bootstrap_acl {
  local func="bootstrap_acl"
  local cip="$1"
  log "INFO" "${func}" "Bootstrapping ACLs"
  ret=`ssh -oStrictHostKeyChecking=no $cip "${TMP_DIR}/install_final.sh --bs-acl"`
  echo $ret | cut -d'"' -f4
}

function set_agent_token {
  local func="set_agent_token"
  local cip="$1"
  local MT="$2"
  log "INFO" "${func}" "Setting Agent Token ACLs"
  ret=`ssh -oStrictHostKeyChecking=no $cip "${TMP_DIR}/install_final.sh --set_agent $MT"`
  echo $ret | cut -d'"' -f4
}

function update_consul_hcl {
  local func="update_consul_hcl"
  local ip="$1"
  local at="$2"
  log "INFO" "${func}" "updating consul HCL"
  ret=`ssh -oStrictHostKeyChecking=no $ip "${TMP_DIR}/install_final.sh --update-consul-hcl $at"`
}

function update_vault_hcl {
  local func="update_vault_hcl"
  local ip="$1"
  local vt="$2"
  log "INFO" "${func}" "updating consul HCL"
  ret=`ssh -oStrictHostKeyChecking=no $ip "${TMP_DIR}/install_final.sh --update-vault-hcl $vt"`
}

function install {
  local func="install"
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

# Global variables
  MT=''
  AT=''
  VT=''

# SSH to first consul server and start it
  local consul_server=`echo $CONSUL_IPS|cut -d',\' -f1`
  consul_cluster_action "start" "$consul_server"
# SSH to first consul server and bootstrap ACL
  MT=`bootstrap_acl "$consul_server"`
  log "INFO" $func "Management token for consul = $MT"
# SSH to first consul server and set agent Token
  AT=`set_agent_token "$consul_server" $MT`
  log "INFO" $func "Agent token for consul = $AT"
# SSH to all consul servers and agents and set agent Token
  for ip in `echo $CONSUL_IPS $VAULT_IPS | awk -F, ' for (i=1; i<=NF; i++) print $i}'`
  do
    update_consul_hcl "$ip" "$AT"
  done
# SSH to first consul server and set vault Token
  VT=`set_vault_token $consul_server $MT`
  log "INFO" $func "Vault token for consul = $VT"
# SSH to all vault servers and set vault Token
  for ip in `echo $VAULT_IPS | awk -F, ' for (i=1; i<=NF; i++) print $i}'`
  do
    update_vault_hcl "$ip" "$VT"
  done
# SSH to first consul server and stop it
  consul_cluster_action "stop" "$consul_server"

}

install "$@"
