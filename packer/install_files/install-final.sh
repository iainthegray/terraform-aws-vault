#!/bin/bash
# This script is used to do the final config of vault and consul as per the
# deployment guide: https://www.vaultproject.io/guides/operations/deployment-guide.html

TMP_DIR="/tmp/ins"

function log {
  local -r level="$1"
  local -r func="$2"
  local -r message="$3"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [${func}] ${message}"
}

function bootstrap_acl {
  local func="bootstrap_acl"
  MT=`curl --request PUT http://127.0.0.1:8500/v1/acl/bootstrap |cut -d'"' -f4`
  echo $MT
}

function set_agent {
  local func="set_agent"
  local mt="$1"
  AT=`curl  --request PUT  --header "X-Consul-Token: ${mt}" --data '{"Name": "Agent Token", "Type": "client", "Rules": "node \"\" { policy = \"write\" } service \"\" { policy = \"read\" }"}' http://127.0.0.1:8500/v1/acl/create | cut -d'"' -f4`
  echo $AT
}

function update_consul {
  local func="update_consul"
  local at="$1"
  sudo sed -i'' "s/# acl_agent_token = {{ acl_token }}/acl_agent_token = \"$at\"/" /etc/consul.d/consul.hcl
}

function update_vault {
  local func="update_vault"
  local at="$1"
  sudo sed -i'' "s/{{ vault_token }}/$at/" /etc/vault.d/vault.hcl
}

function add_auto_unseal {
  local func="add_auto_unseal"
  local k="$1"
  local r="$2"
  sudo sed -i'' "s/#//g" /etc/vault.d/vault.hcl
  sudo sed -i'' "s/{{ kms_key }}/$k/" /etc/vault.d/vault.hcl
  sudo sed -i'' "s/{{ aws_region }}/$r/" /etc/vault.d/vault.hcl
}

function set_vault {
  local func="set_vault"
  local mt="$1"
  VT=`curl --request PUT  --header "X-Consul-Token: ${mt}" --data '{"Name": "Vault Token", "Type": "client", "Rules": "node \"\" { policy = \"write\" } service \"vault\" { policy = \"write\" } agent \"\" { policy = \"write\" }  key \"vault\" { policy = \"write\" } session \"\" { policy = \"write\" } "}' http://127.0.0.1:8500/v1/acl/create | cut -d'"' -f4`
  echo $VT
}

function strip_acl_comments {
  local func="strip_acl_comments"
  sudo sed -i'' "s/# acl_d/acl_d/g" /etc/consul.d/consul.hcl
}

function install {
  local func="install"
  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --bs-acl)
        bootstrap_acl
        exit
        ;;
      --set-agent)
        mt="$2"
        set_agent $mt
        exit
        ;;
      --set-vault)
        mt="$2"
        set_vault $mt
        exit
        ;;
      --update-consul-hcl)
        at="$2"
        update_consul $at
        exit
        ;;
      --update-vault-hcl)
        at="$2"
        update_vault $at
        exit
        ;;
      --add-auto-unseal)
        k="$2"
        r="$3"
        add_auto_unseal $k $r
        exit
        ;;
      --strip-acl-comment)
        strip_acl_comments
        exit
        ;;
      *)
        log "ERROR" $func "Unrecognized argument: $key"
        exit 1
        ;;
    esac

    shift
  done
}

install "$@"
