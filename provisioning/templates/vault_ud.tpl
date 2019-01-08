#!/bin/bash


function has_yum {
  [ -n "$(command -v yum)" ]
}

function has_apt_get {
  [ -n "$(command -v apt-get)" ]
}

function do_install {
  if $(has_apt_get); then
    sudo apt-get update -y
    sudo apt-get install -y awscli curl unzip jq
  elif $(has_yum); then
    sudo yum install -y unzip jq
    sudo yum install -y epel-release
    sudo yum install -y python-pip
    sudo pip install awscli
  else
    log_error "Could not find apt-get or yum. Cannot install dependencies on this OS."
    exit 1
  fi

  cd /tmp
  mkdir ins
  aws s3 cp "s3://${install_bucket}/Packer/install-consul.sh" ins
  aws s3 cp "s3://${install_bucket}/Packer/install-vault.sh" ins
  bash ins/install-consul.sh --install-bucket ${install_bucket} --version ${consul_version} --client 1 --tag "${cluster_tag}" --cluster-size ${consul_cluster_size}
  bash ins/install-vault.sh --install-bucket ${install_bucket} --vault-bin ${vault_bin} --key ${key_pem} --cert  ${cert_pem}
}

echo "USE USERDATA = ${use_userdata}"
if [ ${use_userdata} -eq 1 ]
then
  do_install
else
  exit
fi
