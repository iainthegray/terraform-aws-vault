#!/bin/bash
# This script is used to do the final config of vault and consul as per the
# deployment guide: https://www.vaultproject.io/guides/operations/deployment-guide.html

TMP_DIR="/tmp/ins"

function print_usage {
  echo
  echo "Usage: final_config.sh [OPTIONS]"
  echo "Options:"
  echo
  echo -e "  --consul-ips\t\t A comma separated string in \" no spaces of consul server IPs. Required"
  echo
  echo -e "  --vault-ips\t\t A comma separated string in \" no spaces of vault server IPs. Required"
  echo
  echo -e "  --kms-key\t\t The id of the kms key if you are using auto-unseal"
  echo
  echo -e "  --kms-region\t\t The region of the kms key if you are using auto-unseal"
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
    echo $alive
}

function bootstrap_acl {
  local func="bootstrap_acl"
  local cip="$1"
  log "INFO" "${func}" "Bootstrapping ACLs on host $cip"
  ret=`ssh -oStrictHostKeyChecking=no $cip "bash ${TMP_DIR}/install-final.sh --bs-acl"`
  echo $ret | cut -d'"' -f4
}

function set_agent_token {
  local func="set_agent_token"
  local cip="$1"
  local MT="$2"
  log "INFO" "${func}" "Setting Agent Token ACLs"
  ret=`ssh -oStrictHostKeyChecking=no $cip " bash ${TMP_DIR}/install-final.sh --set-agent $MT"`
  echo $ret | cut -d'"' -f4
}

function set_vault_token {
  local func="set_vault_token"
  local cip="$1"
  local MT="$2"
  log "INFO" "${func}" "Setting Vault ACL Token"
  ret=`ssh -oStrictHostKeyChecking=no $cip " bash ${TMP_DIR}/install-final.sh --set-vault $MT"`
  echo $ret | cut -d'"' -f4
}

function update_consul_hcl {
  local func="update_consul_hcl"
  local ip="$1"
  local at="$2"
  log "INFO" "${func}" "updating consul HCL with Agent Token $at"
  ret=`ssh -oStrictHostKeyChecking=no $ip "bash ${TMP_DIR}/install-final.sh --update-consul-hcl $at"`
}

function update_vault_hcl {
  local func="update_vault_hcl"
  local ip="$1"
  local vt="$2"
  log "INFO" "${func}" "updating vault HCL"
  ret=`ssh -oStrictHostKeyChecking=no $ip "bash ${TMP_DIR}/install-final.sh --update-vault-hcl $vt"`
}

function add_auto_unseal {
  local func="add_auto_unseal"
  local ip="$1"
  local key="$2"
  local reg="$3"
  log "INFO" "${func}" "updating vault HCL"
  ret=`ssh -oStrictHostKeyChecking=no $ip "bash ${TMP_DIR}/install-final.sh --add-auto-unseal $key $reg"`
}

function strip_acl_comments {
  local func="strip_acl_comments"
  local ip="$1"
  log "INFO" "${func}" "Allowing ACL to run on $ip"
  ret=`ssh -oStrictHostKeyChecking=no $ip "bash ${TMP_DIR}/install-final.sh --strip-acl-comment"`
}

function check_consul_up {
  local func="update_vault_hcl"
  local ip="$1"
  local MT="$2"
  ret=`ssh -oStrictHostKeyChecking=no $ip CONSUL_HTTP_TOKEN="$MT" consul members -status=alive | grep -v "^Node" | wc -l`
  echo $ret
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
      --kms-key)
        KEY_ID="$2"
        shift
        ;;
      --kms-region)
        KEY_REGION="$2"
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
  log "INFO" $func "Installing to these consul servers $CONSUL_IPS"
  log "INFO" $func "Installing to these vault servers $VAULT_IPS"
  # remove the commenting from the ACL lines in consul
  for ip in `echo $CONSUL_IPS $VAULT_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
  do
    strip_acl_comments "$ip"
  done
  # SSH to first consul server and start it
  for ip in `echo $CONSUL_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
  do
    consul_action start $ip
  done
# SSH to first consul server and bootstrap ACL
  log "INFO" "MAIN" "sleeping 5"
  sleep 5
  log "INFO" "MAIN" "sleeping 10"
  sleep 5
  consul_server=`echo $CONSUL_IPS | awk -F, '{print $1}'`
  MT=`bootstrap_acl "$consul_server"`
  log "INFO" $func "Management token for consul = $MT"
  alive=`check_consul_up $consul_server $MT`
  log "INFO" $func "Consul servers alive = $alive"
# SSH to first consul server and set agent Token
  AT=`set_agent_token "$consul_server" $MT`
  log "INFO" $func "Agent token for consul = $AT"
# SSH to all consul servers and agents and set agent Token
  for ip in `echo $CONSUL_IPS $VAULT_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
  do
    update_consul_hcl "$ip" "$AT"
  done
# SSH to first consul server and set vault Token
  VT=`set_vault_token $consul_server $MT`
  log "INFO" $func "Vault token for consul = $VT"
# SSH to all vault servers and set vault Token
  for ip in `echo $VAULT_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
  do
    update_vault_hcl "$ip" "$VT"
  done
# SSH to first consul server and stop it
  for ip in `echo $CONSUL_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
  do
    consul_action "stop" "$ip"
  done
  log "INFO" $func "KMS_KEY = $KEY_ID KMS_REG = $KEY_REGION"
  if [ -n "$KEY_ID" -a -n "$KEY_REGION" ]
  then
    for ip in `echo $VAULT_IPS | awk -F, '{for (i=1; i<=NF; i++) print $i}'`
    do
      add_auto_unseal "$ip" "$KEY_ID" "$KEY_REGION"
    done
  fi
}

install "$@"
