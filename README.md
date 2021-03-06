# OpenVPN Setup on AWS EC2 via Terraform

- Fully Automated OpenVPN Setup Using Terraform

- Creates an EC2 instance in a new VPC

- Creates Security Groups to allow only OpenVPN and ssh connections

- SSH on a non standard port

- Configures UFW to allow only SSH and OpenVPN connections

- Configures CloudWatch Alarms for CPU and EBS Disk utilization

- Installs ClamAV

- Configures EC2 Backup on AWS Backup

- Post Setup, Connection to the server is possible only via the VPN connection

# Terraform and Awscli installation on MacOS Big Sur

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" # Install Homebrew

brew install terraform awscli # Install Terraform and awscli
brew cask install openvpn-connect # Install OpenVPN Client

```

Setup awscli on your client system , with an account which has sufficient administrative privileges

```shell
aws configure
```

# Launch Terraform to run the script

Check and configure values in the terraform/variables.tf file e.g. AWS region, EC2 instance type, email address to send alerts to etc.

```shell
git clone https://github.com/sharjeelsayed/terraform-openvpn-ec2-server.git
cd terraform-openvpn-ec2-server/terraform && terraform init && terraform plan && terraform apply -auto-approve
```

Post run, download the client.opvn file from the server and run the post install script

```shell
server_ip=$(terraform output public_instance_ip) ; rsync -avz -e 'ssh -i eltopenvpn-key-pair.pem' ubuntu@$server_ip:/home/ubuntu/client.ovpn .

ssh -i "./eltopenvpn-key-pair.pem" ubuntu@$server_ip
chmod +x /tmp/post_install.sh
/tmp/post_install.sh
```

Import the client.opvn configuration file in your OpenVPN client and connect.

You will now be able to ssh to your OpenVPN server via the OpenVPN connection only.

```shell
ssh -p 2222 -i "terraform/eltopenvpn-key-pair.pem" ubuntu@10.8.0.1
```

# EBS Disk Utilization CloudWatch Alarm manual Setup Steps

The Terraform script does the major work for the EBS Disk Utilization CloudWatch Alarm setup but a few additional last steps are required to be done manually as CloudWatch does not offer default metrics for EBS disk utilization.

```shell
ssh -p 2222 -i "terraform/eltopenvpn-key-pair.pem" ubuntu@10.8.0.1

sudo vi /home/cwagent/.aws/credentials # Add key id and access key
sudo vi /home/cwagent/.aws/config # Enter the following values
#[default]
#region = us-east-1
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
sudo systemctl enable amazon-cloudwatch-agent.service
sudo systemctl restart amazon-cloudwatch-agent
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log

```

Open the AWS Management Console and switch to the CloudWatch service.  
Select Alarms from the sub-navigation and press the Create alarm button.  
Click the Select metric button.Search for the custom namespace CWAgent.  
Click the InstanceId, device, fstype, path link.  
Search for the metric with the InstanceId of your EC2 instance and the mount path that you want to monitor.  
For example, the mount path /. Then, select the metric and press the Select metric button.Configure a threshold for the alarm.  
For example, I want to get notified when the disk usage is higher than 90%, which means less than 10% disk space is available.  
Configure a notification to make sure you get notified whenever your EC2 instance runs out of disk space.  
You can do so by creating a new SNS topic and adding your e-mail address.  
Press the Next button.  
Click the Create alarm button and add your email address to send alerts
