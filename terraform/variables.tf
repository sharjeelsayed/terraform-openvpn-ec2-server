variable "AWS_REGION" {
  type = string
  default = "us-east-1"
}

variable "INSTANCE_TYPE" {
  type    = string
  default = "t2.micro"
}

variable "INSTANCE_NAME" {
  type    = string
  default = "eltopenvpn"
}

variable "VPC_CIDR" {
  type    = string
  default = "10.0.1.0/24"
}

variable "SUBNET1_CIDR" {
  type    = string
  default = "10.0.1.0/25"
}

variable "KEY_PAIR_NAME" {
  type    = string
  default = "eltopenvpn-key-pair"
}

variable "SSH_USER" {
  type    = string
  default = "ubuntu"
}

variable "SSH_PORT" {
  description = "The port the EC2 Instance should listen on for SSH requests."
  type        = number
  default     = 22
}

variable "ALARMS_EMAIL" {
  type    = string
  default = "example@exmple.com"
}