output "public_instance_id" {
  value = aws_instance.main.id
}

output "public_instance_ip" {
  value = aws_instance.main.public_ip
}

#output "private_key" {
#  value = tls_private_key.main.private_key_pem
#}