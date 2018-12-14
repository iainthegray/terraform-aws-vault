#!/bin/bash
# This script can be used to install Vault as per the deployment guide:
# https://www.vaultproject.io/guides/operations/deployment-guide.html

# operating systems tested on:
#
# 1. Ubuntu 18.04
# https://aws.amazon.com/marketplace/pp/B07CQ33QKV
# 1. Centos 7
# https://aws.amazon.com/marketplace/pp/B00O7WM7QW

set -e

readonly DEFAULT_INSTALL_PATH="/usr/local/bin/vault"
readonly DEFAULT_VAULT_USER="vault"
readonly DEFAULT_VAULT_PATH="/etc/vault.d/"
readonly DEFAULT_VAULT_CONFIG="vault.hcl"
readonly DEFAULT_VAULT_SERVICE="/etc/systemd/system/vault.service"
readonly DEFAULT_VAULT_CERTS="/etc/vault.d/certs"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TMP_DIR="/tmp/install"
readonly TMP_ZIP="vault.zip"
readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-vault [OPTIONS]"
  echo "Options:"
  echo
  echo -e "  --install-bucket\t\tThe S3 location of a folder that contains all the install artifacts. Required"
  echo
  echo -e "  --vault-bin\t\t The name of the vault binary (zip) to install. (must be in the S3 bucket above) Required."
  echo
  echo -e "  --key\t\t The name of the private key file for vault TLS. (must be in the S3 bucket above). Required."
  echo
  echo -e "  --cert\t\t The name of the cert file for vault TLS. (must be in the S3 bucket above). Required."
  echo
  echo "This script can be used to install Vault and its dependencies. This script has been tested with Ubuntu 18.04 and Centos 7."
  echo
}

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function has_yum {
  [ -n "$(command -v yum)" ]
}

function has_apt_get {
  [ -n "$(command -v apt-get)" ]
}

function install_dependencies {
  log_info "Installing dependencies"

  if $(has_apt_get); then
    sudo apt-get update -y
    sudo apt-get install -y awscli curl unzip jq
  elif $(has_yum); then
    sudo yum update -y
    sudo yum install -y unzip jq
    sudo yum install -y epel-release
    sudo yum install -y python-pip
    sudo pip install awscli
  else
    log_error "Could not find apt-get or yum. Cannot install dependencies on this OS."
    exit 1
  fi
}

function user_exists {
  local -r username="$1"
  id "$username" >/dev/null 2>&1
}

function create_vault_user {
  local -r username="$1"

  if $(user_exists "$username"); then
    log_info "User $username already exists. Will not create again."
  else
    log_info "Creating user named $username"
    sudo useradd --system --home /etc/vault.d --shell /bin/false $username
  fi
}

function create_vault_install_paths {
  local -r path="$1"
  local -r c_path="$2"
  local -r username="$3"
  local -r config="$4"
  local -r key="$5"
  local -r cert="$6"

  log_info "Creating install dirs for Vault at $path"
  sudo mkdir -p "$path"
  sudo mkdir -p "$c_path"
  sudo cat << EOF > ${TMP_DIR}/outy

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "${c_path}/${cert}"
  tls_key_file  = "${c_path}/${key}"
}

storage "consul" {
  address = 127.0.0.1:8500
  path = "vault"
}

ui = true
api_addr = "{{full URL to Vault API endpoint}}"
EOF

  sudo cp ${TMP_DIR}/outy ${path}$config
  sudo chmod 640 ${path}$config
  log_info "Changing ownership of $path to $username"
  sudo chown -R "$username:$username" "$path"
}

function get_vault_binary {

  local -r loc="$1"
  local -r bin="$2"
  local -r tmp="$3"
  local -r zip="$4"

  log_info "Copying vault binary to local"
  aws s3 cp ${loc}/${bin} "${tmp}/${zip}"
  ex_c=$?
  log_info "s3 copy exit code == $ex_c"
  if [ $ex_c -ne 0 ]
  then
    log_error "The copy of the vault binary from ${loc}/${bin} failed"
    exit
  else
    log_info "Copy of vault binary successful"
  fi
  unzip -tqq ${tmp}/${zip}
  if [ $? -ne 0 ]
  then
    log_error "Supplied Vault binary is not a zip file"
    exit
  fi
}

function install_vault {
  local -r loc="$1"
  local -r tmp="$2"
  local -r zip="$3"


  log_info "Installing Vault"
  cd ${tmp} && unzip -q ${zip}
  sudo chown root:root vault
  sudo mv vault $loc
  sudo setcap cap_ipc_lock=+ep $loc
}

function install_vault_tls_keys {
  local -r bucket="$1"
  local -r key="$2"
  local -r cert="$3"
  local -r path="$4"
  log_info "Copying TLS keys binary to local"
  aws s3 cp ${bucket}/${key} "${TMP_DIR}"
  ex_c=$?
  log_info "key copy exit code == $ex_c"
  if [ $ex_c -ne 0 ]
  then
    log_error "The copy of the key from ${bucket}/${key} failed"
    exit
  else
    log_info "Copy of key successful"
  fi

  aws s3 cp ${bucket}/${cert} "${TMP_DIR}"
  ex_c=$?
  log_info "cert copy exit code == $ex_c"
  if [ $ex_c -ne 0 ]
  then
    log_error "The copy of the cert from ${loc}/${bin} failed"
    exit
  else
    log_info "Copy of cert successful"
  fi

  sudo cp ${TMP_DIR}/${key} ${TMP_DIR}/${cert} $path
  sudo chown -R root:root $c_path
  sudo chmod 400 ${path}/${key} ${path}/${cert}
}

function create_vault_service {
  local -r service="$1"

  log_info "Creating Vault service"
  cat <<EOF > /tmp/outy
[Unit]]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitIntervalSec=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

  sudo cp /tmp/outy $service
  sudo systemctl enable vault

}

function install {
  mkdir $TMP_DIR
  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --help)
        print_usage
        exit
        ;;
      --install-bucket)
        ib="$2"
        shift
        ;;
      --vault-bin)
        vb="$2"
        shift
        ;;
      --key)
        k="$2"
        shift
        ;;
      --cert)
        c="$2"
        shift
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--install-bucket" "$ib"
  assert_not_empty "--vault-bin" "$vb"
  assert_not_empty "--key" "$k"
  assert_not_empty "--cert" "$c"

  log_info "Starting Vault install"
  install_dependencies
  create_vault_user "$DEFAULT_VAULT_USER"
  get_vault_binary "$ib" "$vb" "$TMP_DIR" "$TMP_ZIP"
  install_vault "$DEFAULT_INSTALL_PATH" "$TMP_DIR" "$TMP_ZIP"
  create_vault_install_paths "$DEFAULT_VAULT_PATH" "$DEFAULT_VAULT_CERTS" "$DEFAULT_VAULT_USER" "$DEFAULT_VAULT_CONFIG" "$k" "$c"
  install_vault_tls_keys "$ib" "$k" "$c" "$DEFAULT_VAULT_CERTS"
  create_vault_service "$DEFAULT_VAULT_SERVICE"
  log_info "Vault install complete!"
  sudo rm -rf $TMP_DIR
}

install "$@"
