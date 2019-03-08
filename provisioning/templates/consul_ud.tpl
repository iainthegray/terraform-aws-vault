#!/bin/bash

function has_yum {
  [ -n "$(command -v yum)" ]
}

function has_apt_get {
  [ -n "$(command -v apt-get)" ]
}

function log {
  local -r level="$1"
  local -r func="$2"
  local -r message="$3"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "$${timestamp} [$${level}] [$${func}] $${message}"
}

function do_install {
  local -r func="do_install"
  if $(has_apt_get); then
    log "INFO" "$func" "This is a debian based install - using apt"
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
    sudo apt-get install -y awscli curl unzip jq
  elif $(has_yum); then
    log "INFO" "$func" "This is a redhat based install - using yum"
    sudo yum install -y unzip jq
    sudo yum install -y epel-release
    sudo yum install -y python-pip
    sudo pip install awscli
  else
    log "ERROR" "$func" "Could not find apt-get or yum. Cannot install dependencies on this OS."
    exit 1
  fi

  cd /tmp

  log "INFO" "$func" "Creating install dir /tmp/install_files"
  mkdir install_files
  log "INFO" "$func" "copying consul install script"
  aws s3 cp "s3://${install_bucket}/install_files/install-consul.sh" install_files
  log "INFO" "$func" "copying vault install script"
  aws s3 cp "s3://${install_bucket}/install_files/install-vault.sh" install_files
  log "INFO" "$func" "copying final install script"
  aws s3 cp "s3://${install_bucket}/install_files/install-final.sh" install_files
  if [[ -z "${consul_version}" ]]
  then
    log "INFO" "$func" "Doing a binary install from S3 for consul"
    bash install_files/install-consul.sh --install-bucket ${install_bucket} --consul-bin ${consul_bin} --client 0 --tag "${cluster_tag}" --cluster-size ${consul_cluster_size}
  else
    log "INFO" "$func" "Doing a download install from releases for consul"
    bash install_files/install-consul.sh --install-bucket ${install_bucket} --version ${consul_version} --client 0 --tag "${cluster_tag}" --cluster-size ${consul_cluster_size}
  fi
}

if [ ${use_userdata} -eq 1 ]
then
  do_install
else
  exit
fi
