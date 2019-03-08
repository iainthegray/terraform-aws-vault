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
readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-vault [OPTIONS]"
  echo "Options:"
  echo
  echo -e "  --install-bucket\t\tThe S3 location of a folder that contains all the install artifacts. Required"
  echo
  echo -e " one of the following 2 options:"
  echo -e "  --vault-bin\t\t The name of the vault binary (zip) to install. (must be in the S3 bucket above) Required."
  echo -e "or..."
  echo -e "  --version\t\t The vault version required to be downloaded from Hashicorp Releases. Required."
  echo
  echo -e "  --key\t\t The name of the private key file for vault TLS. (must be in the S3 bucket above). Required."
  echo
  echo -e "  --cert\t\t The name of the cert file for vault TLS. (must be in the S3 bucket above). Required."
  echo
  echo -e "  --api_addr\t\t The api_addr to use. This will be either the host or the URL of the loadbalancer. Required."
  echo
  echo "This script can be used to install Vault and its dependencies. This script has been tested with Ubuntu 18.04 and Centos 7."
  echo
}

function log {
  local -r level="$1"
  local -r func="$2"
  local -r message="$3"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [${SCRIPT_NAME}:${func}] ${message}"
}

function assert_not_empty {
  local func="assert_not_empty"
  local -r arg_name="$1"
  local -r arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log "ERROR" $func "The value for '$arg_name' cannot be empty"
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
  local func="install_dependencies"
  log "INFO" $func "Installing dependencies"

  if $(has_apt_get); then
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
    sudo apt-get install -y awscli curl unzip jq
  elif $(has_yum); then
    # sudo yum update -y
    sudo yum install -y unzip jq
    sudo yum install -y epel-release
    sudo yum install -y python-pip
    sudo pip install awscli
  else
    log "ERROR" $func "Could not find apt-get or yum. Cannot install dependencies on this OS."
    exit 1
  fi
}

function user_exists {
  local -r username="$1"
  id "$username" >/dev/null 2>&1
}

function create_vault_user {
  local func="create_vault_user"
  local -r username="$1"

  if $(user_exists "$username"); then
    log "INFO" $func "User $username already exists. Will not create again."
  else
    log "INFO" $func "Creating user named $username"
    sudo useradd --system --home /etc/vault.d --shell /bin/false $username
  fi
}

function create_vault_install_paths {
  local func="create_vault_install_paths"
  local -r path="$1"
  local -r c_path="$2"
  local -r username="$3"
  local -r config="$4"
  local -r key="$5"
  local -r cert="$6"
  local -r a_ad="$7"

  log "INFO" $func "Creating install dirs for Vault at $path"
  sudo mkdir -p "$path"
  sudo mkdir -p "$c_path"
  # VT=`cat /etc/consul.d/vt.txt`
  if [ "X${a_ad}" == "Xhost" ]
  then
    api_add=`hostname -I | sed 's/ //'`
  else
    api_add="${a_ad}"
  fi

  sudo cat << EOF > ${TMP_DIR}/outy

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/ssl/certs/${cert}"
  tls_key_file  = "${c_path}/${key}"
}

storage "consul" {
  address = "127.0.0.1:8500"
  path = "vault/"
  token = "{{ vault_token }}"
}

ui = true

api_addr = "https://${api_add}:8200"


#seal "awskms" {
#  kms_key_id = "{{ kms_key }}"
#  region = "{{ aws_region }}"
#}

EOF

  sudo cp ${TMP_DIR}/outy ${path}$config
  sudo chmod 640 ${path}$config
  log "INFO" $func "Changing ownership of $path to $username"
  sudo chown -R "$username:$username" "$path"
}

function get_vault_binary {
  local func="get_vault_binary"
  local -r bin="$1"
  local -r zip="$TMP_ZIP"
  local -r tmp="$TMP_DIR"
  local -r ver="$v"

  if [[ -z $bin ]]
  then
    assert_not_empty "--version" $v
    log "INFO" $func "Copying vault version $ver binary to local"
    cd $tmp
    curl -O https://releases.hashicorp.com/vault/${ver}/vault_${ver}_linux_386.zip
    curl -Os https://releases.hashicorp.com/vault/${ver}/vault_${ver}_SHA256SUMS
    curl -Os https://releases.hashicorp.com/vault/${ver}/vault_${ver}_SHA256SUMS.sig
    shasum -a 256 -c vault_${ver}_SHA256SUMS 2> /dev/null |grep vault_${ver}_linux_386.zip| grep OK
    ex_c=$?
    if [ $ex_c -ne 0 ]
    then
      log "ERROR" $func "The copy of the vault binary failed"
      exit
    else
      log "INFO" $func "Copy of vault binary successful"
    fi
    unzip -tqq ${TMP_DIR}/${zip}
    if [ $? -ne 0 ]
    then
      log "ERROR" $func "Supplied vault binary is not a zip file"
      exit
    fi
  else
    assert_not_empty "--vault-bin" "$bin"
    log "INFO" $func "Copying vault binary from $ib"
    log "INFO" $func "s3://${ib}/install_files/${bin}  ${tmp}/${zip}"
    aws s3 cp "s3://${ib}/install_files/${bin}" "${tmp}/${zip}"
    ex_c=$?
    log "INFO" $func "s3 copy exit code == $ex_c"
    if [ $ex_c -ne 0 ]
    then
      log "ERROR" $func "The copy of the vault binary from ${loc}/${bin} failed"
      exit
    else
      log "INFO" $func "Copy of vault binary successful"
    fi
    unzip -tqq ${tmp}/${zip}
    if [ $? -ne 0 ]
    then
      log "ERROR" $func "Supplied Vault binary is not a zip file"
      exit
    fi
  fi
}

function install_vault {
  local func="install_vault"
  local -r loc="$1"
  local -r tmp="$2"
  local -r zip="$3"


  log "INFO" $func "Installing Vault"
  cd ${tmp} && unzip -q ${zip}
  sudo chown root:root vault
  sudo mv vault $loc
  sudo setcap cap_ipc_lock=+ep $loc
}

function install_vault_tls_keys {
  local func="install_vault_tls_keys"
  local -r bucket="$1"
  local -r key="$2"
  local -r cert="$3"
  local -r path="$4"
  log "INFO" $func "Copying TLS keys binary to local"
  aws s3 cp "s3://${bucket}/install_files/${key}" "${TMP_DIR}"
  ex_c=$?
  log "INFO" $func "key copy exit code == $ex_c"
  if [ $ex_c -ne 0 ]
  then
    log "ERROR" $func "The copy of the key from ${bucket}/${key} failed"
    exit
  else
    log "INFO" $func "Copy of key successful"
  fi

  aws s3 cp "s3://${bucket}/install_files/${cert}" "${TMP_DIR}"
  ex_c=$?
  log "INFO" $func "cert copy exit code == $ex_c"
  if [ $ex_c -ne 0 ]
  then
    log "ERROR" $func "The copy of the cert from ${loc}/${bin} failed"
    exit
  else
    log "INFO" $func "Copy of cert successful"
  fi

  sudo cp ${TMP_DIR}/${key} $path
  sudo cp ${TMP_DIR}/${cert} /etc/ssl/certs/
  sudo chown -R vault:vault $path
  sudo chmod 400 ${path}/${key}
}

function create_vault_service {
  local func="create_vault_service"
  local -r service="$1"

  log "INFO" $func "Creating Vault service"
  cat <<EOF > /tmp/outy
[Unit]
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
  local func="install"
  if [ -e $TMP_DIR ]
  then
    rm -rf $TMP_DIR
  fi
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
        TMP_ZIP="vault.zip"
        shift
        ;;
      --version)
        v="$2"
        TMP_ZIP="vault_${v}_linux_386.zip"
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
      --api_addr)
        a_ad="$2"
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

  assert_not_empty "--install-bucket" "$ib"
  assert_not_empty "--key" "$k"
  assert_not_empty "--cert" "$c"
  assert_not_empty "--api_addr" "$a_ad"

  log "INFO" $func "Starting Vault install"
  install_dependencies
  create_vault_user "$DEFAULT_VAULT_USER"
  get_vault_binary "$vb"
  install_vault "$DEFAULT_INSTALL_PATH" "$TMP_DIR" "$TMP_ZIP"
  create_vault_install_paths "$DEFAULT_VAULT_PATH" "$DEFAULT_VAULT_CERTS" "$DEFAULT_VAULT_USER" "$DEFAULT_VAULT_CONFIG" "$k" "$c" "$a_ad"
  install_vault_tls_keys "$ib" "$k" "$c" "$DEFAULT_VAULT_CERTS"
  create_vault_service "$DEFAULT_VAULT_SERVICE"
  log "INFO" $func "Vault install complete!"
  sudo rm -rf $TMP_DIR
}

install "$@"
