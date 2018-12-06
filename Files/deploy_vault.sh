#!/usr/bin/env bash

# Bash script to deploy Vault as per the DG:
# https://learn.hashicorp.com/vault/operations/ops-deployment-guide

# Input variables:
S3_BUCKET_OBJ=""

# Script globals
TMP_DIR=/tmp/install
TMP_ZIP=vault.zip
# Copy the binary to your server. This should be hosted in a private S3 bucket
# that is created in the module and passed by variable
mkdir ${TMP_DIR}
aws s3 cp ${S3_BUCKET_OBJ} ${TMP_DIR}/${TMP_ZIP}
# Test the zip file
unzip -tqq ${TMP_DIR}/${TMP_ZIP}
if [ $? ]
then
  echo "Supplied Vault binary is not a zip file"
  exit(3)
fi
cd ${TMP_DIR} && unzip -q ${TMP_ZIP}

# copy the vault binary to /usr/local/bin and set it up
sudo chown root:root vault
sudo mv vault /usr/local/bin/
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault
sudo useradd --system --home /etc/vault.d --shell /bin/false vault
sudo touch /etc/systemd/system/vault.service
cat <<EOT > /etc/systemd/system/vault.service
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
EOT
