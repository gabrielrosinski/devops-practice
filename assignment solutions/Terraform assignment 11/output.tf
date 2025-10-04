output "instance_id" {
    value = aws_instance.ubuntu.id
}

output "public_ip" {
    value = aws_instance.ubuntu.public_ip
}

output "ssh_command" {
    value = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.ubuntu.public_ip}"
}