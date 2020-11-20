#!/bin/bash

logFile="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/$(basename "$0").log"
exec > "$logFile" 2>&1

SshPortChange()
{
# Change SSH_PORT
SSH_PORT=2222
cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
if [ -e "/etc/ssh/sshd_config" ];then
[ -z "`grep ^Port /etc/ssh/sshd_config`" ] && ssh_port=22 || ssh_port=`grep ^Port /etc/ssh/sshd_config | awk '{print $2}'`
while :; do echo
#read -p "Please input SSH port(Default: $ssh_port): " SSH_PORT
[ -z "$SSH_PORT" ] && SSH_PORT=$ssh_port
if [ $SSH_PORT -eq 22 >/dev/null 2>&1 -o $SSH_PORT -gt 1024 >/dev/null 2>&1 -a $SSH_PORT -lt 65535 >/dev/null 2>&1 ];then
break
else
echo "${CWARNING}input error! Input range: 22,1025~65534${CEND}"
fi
done
if [ -z "`grep ^Port /etc/ssh/sshd_config`" -a "$SSH_PORT" != '22' ];then
sudo sed -i "s@^#Port.*@&\nPort $SSH_PORT@" /etc/ssh/sshd_config
elif [ -n "`grep ^Port /etc/ssh/sshd_config`" ];then
sudo sed -i "s@^Port.*@Port $SSH_PORT@" /etc/ssh/sshd_config
fi
fi
sudo systemctl restart ssh
}

UfwSetup()
{
# Setup UFW
sudo ufw status
sudo ufw disable
echo "y" | sudo ufw reset
sudo ufw default allow outgoing
#sudo ufw allow ssh
#sudo ufw allow 2222
sudo ufw allow 1194
#sudo ufw allow in on tun0 to any port 22
sudo ufw allow in on tun0 to any port 2222
echo "y" | sudo ufw enable
sudo ufw status
}

SshPortChange
UfwSetup
