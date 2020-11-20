provider "aws" {
  region = var.AWS_REGION
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "null_resource" "keypair_generate" {
  provisioner "local-exec" {
    command = "aws ec2 delete-key-pair --region ${var.AWS_REGION} --key-name eltopenvpn-key-pair ; rm -f eltopenvpn-key-pair.pem; aws ec2 create-key-pair --region ${var.AWS_REGION} --key-name eltopenvpn-key-pair --query 'KeyMaterial' --output text > eltopenvpn-key-pair.pem && chmod 400 eltopenvpn-key-pair.pem"
  }
}

resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.INSTANCE_TYPE
  key_name      = var.KEY_PAIR_NAME
  subnet_id     = aws_subnet.main.id
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.allow_alternate_ssh.id,
    aws_security_group.allow_vpn.id
  ]

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = var.INSTANCE_NAME
  }

  provisioner "file" {
    source      = "../scripts/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/user_data.sh",
      "/tmp/user_data.sh",
    ]
  }
  depends_on = [null_resource.keypair_generate]
  connection {
    type  = "ssh"
    host  = aws_instance.main.public_ip
    user  = var.SSH_USER
    port  = var.SSH_PORT
    agent = true
    #private_key = var.PRIVATE_KEY_PATH
    private_key = file("./eltopenvpn-key-pair.pem")
  }

}

resource "null_resource" "fetch_opvn" {
  provisioner "local-exec" {
    command = <<-EOT
    #!/bin/bash
    server_ip=$(terraform output public_instance_ip)
    rsync -avz -e 'ssh -i eltopenvpn-key-pair.pem' ubuntu@"$server_ip":/home/ubuntu/client.ovpn .
    EOT
  }
  depends_on = [aws_instance.main]
}

resource "null_resource" "post_install" {
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/post_install.sh",
      "/tmp/post_install.sh",
    ]
    connection {
      type  = "ssh"
      host  = aws_instance.main.public_ip
      user  = var.SSH_USER
      port  = var.SSH_PORT
      agent = true
      #private_key = var.PRIVATE_KEY_PATH
      private_key = file("./eltopenvpn-key-pair.pem")
    }
  }
  depends_on = [null_resource.fetch_opvn]
}


resource "aws_vpc" "main" {
  cidr_block           = var.VPC_CIDR
  enable_dns_hostnames = "true"

  tags = {
    Name = var.INSTANCE_NAME
  }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.SUBNET1_CIDR
  map_public_ip_on_launch = "true"

  tags = {
    Name = var.INSTANCE_NAME
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.INSTANCE_NAME
  }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = var.INSTANCE_NAME
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.r.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "ssh to VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "allow_alternate_ssh" {
  name        = "allow_alternate_ssh"
  description = "Allow ssh inbound traffic on alternate port"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "alternate ssh to VPC"
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_alternate_ssh"
  }
}

resource "aws_security_group" "allow_vpn" {
  name        = "allow_vpn"
  description = "Allow vpn inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "vpn to VPC"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_vpn"
  }
}

resource "aws_cloudwatch_metric_alarm" "main" {
  alarm_name                = "CPU_Util"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "This metric monitors ec2 cpu utilization"
  alarm_actions             = [aws_sns_topic.alarm.arn]
  insufficient_data_actions = []

  dimensions = {
    InstanceId = aws_instance.main.id
  }
}

resource "aws_sns_topic" "alarm" {
  name            = "alarms-topic"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --region ${var.AWS_REGION} --protocol email --notification-endpoint ${var.ALARMS_EMAIL}"
  }
}

resource "aws_backup_vault" "main" {
  name = "main_backup_vault"
  #kms_key_arn = aws_kms_key.example.arn
}

resource "aws_backup_plan" "main" {
  name = "ec2_backup_plan"

  rule {
    rule_name         = "ec2_backup_rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 12 * * ? *)"
    lifecycle {
      delete_after = 7 # delete after 7 days
    }
  }
}

resource "aws_backup_selection" "main" {
  iam_role_arn = aws_iam_role.default.arn
  name         = "ec2_backup_selection"
  plan_id      = aws_backup_plan.main.id

  resources = [aws_instance.main.arn]
}

resource "aws_iam_role" "default" {
  name               = "DefaultBackupRole"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["sts:AssumeRole"],
      "Effect": "allow",
      "Principal": {
        "Service": ["backup.amazonaws.com"]
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "example" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.default.name
}
