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
    cidr_blocks = ["111.88.18.100/32"]
    description = "Allow http traffic from  outside"
  }

  # Allow ssh traffic from outside tp specific ip
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["111.88.18.100/32"]
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


# Create EC2 instance
resource "aws_instance" "devopstest_pub_ec2" {
  ami                    = "ami-05e66df2bafcb7dea" # Amazon Linux 2023(AL2023) AMI
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.devopstest_kp.key_name
  subnet_id              = aws_subnet.devopstest_pub_subnet.id
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.devopstest_pub_sg.id]

  tags = {
    Name = "devopstest-pub-ec2"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    ### --- Update packages ---
    dnf update -y

    ### --- Install Docker ---
    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    # Allow ec2-user to run docker
    usermod -aG docker ec2-user

    ### --- Install Node.js 18 ---
    dnf install -y nodejs npm
    
    ### --- Create application directory ---
    mkdir -p /opt/containerized-helloapp

    ### --- Create Server.JS File ---
    cat > /opt/containerized-helloapp/server.js <<'NODE' 
    const http = require('http');
    const port = process.env.PORT || 80;

    const server = http.createServer((req, res) => {
      if (req.method === 'GET' && req.url === '/hello') {
        res.writeHead(200, {'Content-Type': 'text/plain'});
        res.end('OK');
      } else {
        res.writeHead(404);
        res.end();
      }
    });

    server.listen(port, '0.0.0.0', () =>
      console.log('Server running on port ' + port)
    );

    NODE

    ### --- Create Package.Json File ---
    cat > /opt/containerized-helloapp/package.json <<'JSON'
    {
      "name": "hello-server",
      "version": "1.0.0",
      "main": "server.js",
      "dependencies": {}
    }
    JSON

    ### --- Create DockerFile ---
    cat > /opt/containerized-helloapp/Dockerfile <<'DOCK'
    #------------------------
    # Stage 1: Build the app
    FROM node:18-alpine AS builder

    # Create app directory
    WORKDIR /app

    # Copy app files
    COPY package*.json ./
    COPY server.js ./

    # Install only production deps
    RUN npm install --production

    #--------------------------
    # Stage 2: Production image
    FROM node:18-alpine
    WORKDIR /app

    # Copy only necessary files from builder stage
    COPY --from=builder /app /app

    # Expose the port
    EXPOSE 80

    # Start server
    CMD ["node", "server.js"]
    DOCK

    ### --- Build Docker image ---
    cd /opt/containerized-helloapp
    docker build -t docker-test .

    ### --- Run hello-server app on port 80 both for host and container  ---
    docker run -d -p 80:80 --name devops-test docker-test:latest
    
  EOF

  
}

output "hello_url" {
  value = "http://${aws_instance.devopstest_pub_ec2.public_ip}/hello"
}