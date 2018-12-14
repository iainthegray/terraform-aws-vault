#!/bin/bash
# This script is used to install Consul as a vault backend as per the deployment guide:
# https://www.vaultproject.io/guides/operations/deployment-guide.html

# operating systems tested on:
#
# 1. Ubuntu 18.04
# https://aws.amazon.com/marketplace/pp/B07CQ33QKV
# 1. Centos 7
# https://aws.amazon.com/marketplace/pp/B00O7WM7QW

set -e

readonly DEFAULT_INSTALL_PATH="/usr/local/bin/consul"
readonly DEFAULT_CONSUL_USER="consul"
readonly DEFAULT_CONSUL_PATH="/etc/consul.d/"
readonly DEFAULT_CONSUL_OPT="/opt/consul/"
readonly DEFAULT_CONSUL_CONFIG="consul.hcl"
readonly DEFAULT_CONSUL_SERVICE="/etc/systemd/system/consul.service"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TMP_DIR="/tmp/install"
readonly SCRIPT_NAME="$(basename "$0")"

function print_usage {
  echo
  echo "Usage: install-consul [OPTIONS]"
  echo "Options:"
  echo
  echo -e "  --install-bucket\t\tThe S3 location of a folder that contains all the install artifacts. Required"
  echo
  echo -e "  --version\t\t The consul version required. Required."
  echo
  echo -e "  --client\t\t Should consul be a client no args."
  echo
  echo -e "  --tag\t\t The Consul cluster tag vaslue that should be used for consul cluster joining."
  echo
  echo -e "  --cluster-size\t\t The expected number of servers in the consul cluster."
  echo
  echo "This script can be used to install Consul as a backend to Vault. It has been tested with Ubuntu 18.04 and Centos 7."
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

function create_consul_user {
  local -r username="$1"

  if $(user_exists "$username"); then
    log_info "User $username already exists. Will not create again."
  else
    log_info "Creating user named $username"
    sudo useradd --system --home /etc/consul.d --shell /bin/false $username
  fi
}

function create_consul_install_paths {
  local -r path="$1"
  local -r username="$2"
  local -r config="$3"
  local -r opt="$4"
  local -r client="$5"
  local -r tag_val="$6"
  local -r bs_exp="$7"

  log_info "Creating install dirs for Consul at $path"
  sudo mkdir -p "$path"
  sudo mkdir -p "$opt"

  sudo cat << EOF > ${TMP_DIR}/outy

datacenter = "dc1"
data_dir = "/opt/consul"
encrypt = "{{ key from keygen }}"
retry_join = {
  provider = "aws",
  tag_key = "CONSUL_CLUSTER_TAG"
  tag_value = "${tag_val}"
}
performance {
  raft_multiplier = 1
}
EOF
  if [ ! $client ]
  then
    sudo cat << EOF >> ${TMP_DIR}/outy

server = true
bootstrap_expect = ${bs_exp}
ui = true
EOF

  sudo cp ${TMP_DIR}/outy ${path}$config
  sudo chmod 640 ${path}$config
  log_info "Changing ownership of $path to $username"
  sudo chown -R "$username:$username" "$path"
  sudo chown -R "$username:$username" "$opt"
}

function get_consul_binary {
  local -r ver="$1"

  log_info "Copying consul version $ver binary to local"
  cd $TMP_DIR
  curl -Os https://releases.hashicorp.com/consul/${ver}/consul_${ver}_linux_386.zip
  curl -Os https://releases.hashicorp.com/consul/${ver}/consul_${ver}_SHA256SUMS
  curl -Os https://releases.hashicorp.com/consul/${ver}/consul_${ver}_SHA256SUMS.sig
  shasum -a 256 -c consul_${ver}_SHA256SUMS 2> /dev/null |grep consul_${ver}_linux_386.zip| grep OK
  ex_c=$?
  if [ $ex_c -ne 0 ]
  then
    log_error "The copy of the consul binary failed"
    exit
  else
    log_info "Copy of consul binary successful"
  fi
  echo "consul_${ver}_linux_386.zip"
  if [ $? -ne 0 ]
  then
    log_error "Supplied consul binary is not a zip file"
    exit
  fi
}

function install_consul {
  local -r loc="$1"
  local -r tmp="$2"
  local -r ver="$3"

  log_info "Installing Consul"
  cd ${tmp} && unzip -q consul_${ver}_linux_386.zip
  sudo chown root:root consul
  sudo cp consul $loc
}

function create_consul_service {
  local -r service="$1"

  log_info "Creating Consul service"
  cat <<EOF > /tmp/outy
  [Unit]
  Description="HashiCorp Consul - A service mesh solution"
  Documentation=https://www.consul.io/
  Requires=network-online.target
  After=network-online.target
  ConditionFileNotEmpty=/etc/consul.d/consul.hcl

  [Service]
  User=consul
  Group=consul
  ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
  ExecReload=/usr/local/bin/consul reload
  KillMode=process
  Restart=on-failure
  LimitNOFILE=65536

  [Install]
  WantedBy=multi-user.target
EOF

  sudo cp /tmp/outy $service
  sudo systemctl enable consul

}

function install {
  sudo rm -rf $TMP_DIR
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
      --version)
        v="$2"
        shift
        ;;
      --client)
        c="1"
        shift
        ;;
      --tag)
        tag="$2"
        shift
        ;;
      --cluster-size)
        siz="$2"
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
  assert_not_empty "--version" "$v"
  assert_not_empty "--tag" "$tag"
  assert_not_empty "--cluster-size" "$siz"

  log_info "Starting Consul install"
  install_dependencies
  create_consul_user "$DEFAULT_CONSUL_USER"
  get_consul_binary "$v"
  install_consul "$DEFAULT_INSTALL_PATH" "$TMP_DIR" "$v"
  create_consul_install_paths "$DEFAULT_CONSUL_PATH" "$DEFAULT_CONSUL_USER" "$DEFAULT_CONSUL_CONFIG" "$DEFAULT_CONSUL_OPT" "$c" "$tag" "$siz"
  create_consul_service "$DEFAULT_CONSUL_SERVICE"
  log_info "Vault install complete!"
  sudo rm -rf $TMP_DIR
}

install "$@"
