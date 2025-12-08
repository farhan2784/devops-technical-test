provider "aws" {
  region = "me-central-1" # Set your desired AWS region
}


# Create VPC
resource "aws_vpc" "devopstest_vpc" {
  cidr_block = var.devopstest_VPC_CIDR

  tags = {
    Name = "devopstest-vpc"
  }
}

# Create subnet
resource "aws_subnet" "devopstest_pub_subnet" {
  vpc_id                  = aws_vpc.devopstest_vpc.id
  cidr_block              = var.devopstest_SUBNET_CIDR
  map_public_ip_on_launch = true

  tags = {
    Name = "devopstest-pub-subnet"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "devopstest_igw" {
  vpc_id = aws_vpc.devopstest_vpc.id
  tags = {
    Name = "devopstest-igw"
  }
}

# Create public route table
resource "aws_route_table" "devopstest_public_rt" {
  vpc_id = aws_vpc.devopstest_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devopstest_igw.id
  }

  tags = {
    Name = "devopstest-public-rt"
  }
}

# Associate route table with public subnet
resource "aws_route_table_association" "devopstest_public_assoc" {
  subnet_id      = aws_subnet.devopstest_pub_subnet.id
  route_table_id = aws_route_table.devopstest_public_rt.id
}

# Create security group
resource "aws_security_group" "devopstest_pub_sg" {
  name        = "devopstest-pub-sg"
  description = "Security group for public EC2 instance"
  vpc_id      = aws_vpc.devopstest_vpc.id

  # Allow http traffic from outside
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["111.88.18.21/32"]

    description = "Allow http traffic from  outside"
  }

  # Allow ssh traffic from outside tp specific ip
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["111.88.18.21/32"]
    description = "Allow ssh traffic from outisde to specific source"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devopstest-pub-sg"
  }
}

# Create a KeyPair for EC2
resource "tls_private_key" "devopstest_kp" {
  algorithm = "RSA"
}

resource "aws_key_pair" "devopstest_kp" {
  key_name   = "devopstest-kp"
  public_key = tls_private_key.devopstest_kp.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.devopstest_kp.private_key_pem
  filename = "devopstest-kp.pem"
}

# Create a ECR Repository 
resource "aws_ecr_repository" "hello_repo" {
  name = "hello-server-repo"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    name = "hello-ecr-repo"
  }
}

# Create a role for EC2
resource "aws_iam_role" "devopstest_ec2_role" {
  name = "devopstest-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Create a ECR Policy for EC2
resource "aws_iam_role_policy" "devopstest_ec2_ecr_policy" {
  name = "devopstest-ec2-ecr-policy"
  role = aws_iam_role.devopstest_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer"
      ],
      Resource = "*"
    }]
  })
}

# Create a IAM Instance profile to call in EC2 block
resource "aws_iam_instance_profile" "devopstest_ec2_profile" {
  name = "devopstest-ec2-instance-profile"
  role = aws_iam_role.devopstest_ec2_role.name
}



# Create EC2 instance
resource "aws_instance" "devopstest_pub_ec2" {
  ami                    = "ami-05e66df2bafcb7dea" # Amazon Linux 2023(AL2023) AMI
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.devopstest_kp.key_name
  subnet_id              = aws_subnet.devopstest_pub_subnet.id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.devopstest_pub_sg.id]

  iam_instance_profile = aws_iam_instance_profile.devopstest_ec2_profile.name

  user_data = file("${path.module}/cloud-init.yaml")

  tags = {
    Name = "devopstest-pub-ec2"
  }  

  
}

