# OpenVPN Setup on AWS EC2 via Terraform

- Fully Automated OpenVPN Setup Using Terraform

- Creates an EC2 instance in a new VPC

- Security Groups to allow only OpenVPN and ssh connections

- SSH on 2222 Port

- Configure UFW to allow only SSH and OpenVPN

- CloudWatch Alarms for Disk size and CPU

- ClamAV Install

- EC2 Backup Configuration

# Terraform and awscli installation on MacOS client

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" # Install Homebrew

brew install terraform awscli # Install Terraform and awscli
brew cask install openvpn-connect # Install OpenVPN Client

```

# Launch Terraform to run the script

Check and configure values in the terraform/variables.tf files e.g. AWS region, EC2 instance type, email address to send alerts etc.

```shell
git clone https://github.com/sharjeelsayed/devops-box.git
cd terraform && terraform init && terraform plan && terraform terraform apply -auto-approve
```

Post Terraform run you will find the client.ovpn file in your terraform directory. Import it in your OpenVPN client and connect.

You will now be able to ssh to your OpenVPN server via the OpenVPN connection only.

```shell
ssh -p 2222 -i "./eltopenvpn-key-pair.pem" ubuntu@10.8.0.1
```

# EBS Disk Utilization CloudWatch Alarms manual Setup Steps

Most of the installation is done via the Terraform script. A few steps are required to be done manually as CloudWatch does not offer default metrics for EBS disk utilization

```shell
sudo vi /home/cwagent/.aws/credentials # Add key id and access key
sudo systemctl restart amazon-cloudwatch-agent # Restart Agent

```

Open the AWS Management Console and switch to the CloudWatch service.  
Select Alarms from the sub-navigation and press the Create alarm button.  
Click the Select metric button.Search for the custom namespace CWAgent.  
Please note, it might take up to 5 minutes until new metrics and the custom namespace appear after starting the CloudWatch agent on an EC2 instance.Click the InstanceId, device, fstype, path link.  
Search for the metric with the InstanceId of your EC2 instance and the mount path that you want to monitor.  
For example, the mount path /. Then, select the metric and press the Select metric button.Configure a threshold for the alarm.  
For example, I want to get notified when the disk usage is higher than 90%, which means less than 10% disk space is available.  
Configure a notification to make sure you get notified whenever your EC2 instance runs out of disk space.  
You can do so by creating a new SNS topic and adding your e-mail address.  
Press the Next button.  
Click the Create alarm button
