#!/bin/bash

logFile="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/$(basename "$0").log"
exec > "$logFile" 2>&1

UpdateInstance()
{
# update and upgrade all packages
sudo apt -y update && apt -y upgrade
sudo apt clean
sudo apt autoremove --purge
}

ClamavInstall()
{
# ClamAV Installation
sudo apt install clamav clamav-daemon -y
sudo freshclam
sudo systemctl start clamav-daemon
sudo systemctl enable clamav-daemon
sudo systemctl start clamav-freshclam
sudo systemctl enable clamav-freshclam
}

CloudAgentInstall()
{
sudo apt install awscli -y
curl -s -o /tmp/amazon-cloudwatch-agent.deb https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i /tmp/amazon-cloudwatch-agent.deb
sudo usermod -aG adm cwagent
sudo mkdir -p /home/cwagent/.aws/
#sudo vi /home/cwagent/.aws/credentials # Add key id and access key
#sudo vi /home/cwagent/.aws/config # Enter the following values
#[default]
#region = us-east-1
sudo touch /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
sudo chmod 644 /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
sudo echo "[credentials]" >> /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
sudo echo '    shared_credential_file = "/home/cwagent/.aws/credentials"' >> /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml
sudo cp -a /tmp/amazon-cloudwatch-agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
#sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
#sudo systemctl enable amazon-cloudwatch-agent.service
#sudo systemctl restart amazon-cloudwatch-agent
#sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
}

OpenVpnInstall()
{
# OpenVPN Installation
curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
sudo AUTO_INSTALL=y ./openvpn-install.sh
}

UfwSetup()
{
# Setup UFW
sudo ufw status
sudo ufw disable
echo "y" | sudo ufw reset
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 1194
echo "y" | sudo ufw enable
sudo ufw status
}

UpdateInstance
ClamavInstall
CloudAgentInstall
OpenVpnInstall
UfwSetup
