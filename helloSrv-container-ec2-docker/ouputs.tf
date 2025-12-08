output "ec2_public_ip" {
  value = aws_instance.devopstest_pub_ec2.public_ip
}

output "hello_url" {
  value = "http://${aws_instance.devopstest_pub_ec2.public_ip}/hello"
}

