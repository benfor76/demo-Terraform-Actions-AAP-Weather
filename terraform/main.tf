terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    aap = {
      source  = "ansible/aap"
      version = "~> 1.5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aap" {
  host                 = var.aap_hostname
  token                = var.aap_token
  insecure_skip_verify = true
}

# ==========================================
# 1. NEW INFRASTRUCTURE RESOURCES
# ==========================================

# Create VPC
resource "aws_vpc" "weather_vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true

  tags = {
    Name        = "Bens-Lab-AAP26-vpc"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# Create Subnet
resource "aws_subnet" "weather_subnet" {
  vpc_id                  = aws_vpc.weather_vpc.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "Bens-Lab-AAP26-Subnet"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "weather_igw" {
  vpc_id = aws_vpc.weather_vpc.id

  tags = {
    Name        = "Bens-Lab-AAP26-IGW"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# Create Route Table
resource "aws_route_table" "weather_rt" {
  vpc_id = aws_vpc.weather_vpc.id

  tags = {
    Name        = "Bens-Lab-AAP26-RT"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# Add Default Internet Route
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.weather_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.weather_igw.id
}

# Associate Subnet to Route Table
resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.weather_subnet.id
  route_table_id = aws_route_table.weather_rt.id
}

# Build Security Group
resource "aws_security_group" "weather_sg" {
  name        = "ben-lab-sg"
  description = "Security Group for Weather App Lab Workloads"
  vpc_id      = aws_vpc.weather_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
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
    Name        = "Bens-Lab-AAP26-SG"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# ==========================================
# 2. DYNAMIC SSH KEYPAIR GENERATION
# ==========================================

# Generate a private RSA SSH key
resource "tls_private_key" "demo_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Register the generated public key with AWS
resource "aws_key_pair" "generated_key" {
  key_name_prefix   = "aap-demo-key-"
  public_key = tls_private_key.demo_key.public_key_openssh

  tags = {
    Name        = "AAP-Demo-Dynamic-Key"
    ManagedBy   = "Ansible-and-Terraform"
  }
}

# ==========================================
# 3. COMPUTE & APPLICATION PROVISIONING
# ==========================================

# Discover the latest official RHEL 9 AMI
data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Provision Instance A: Web/App Tier
resource "aws_instance" "web_tier" {
  ami                    = data.aws_ami.rhel9.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.weather_subnet.id
  vpc_security_group_ids = [aws_security_group.weather_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  tags = {
    Name        = "AAP-Demo-Web-Tier"
    Role        = "web"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# Provision Instance B: Database Tier
resource "aws_instance" "db_tier" {
  ami                    = data.aws_ami.rhel9.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.weather_subnet.id
  vpc_security_group_ids = [aws_security_group.weather_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  tags = {
    Name        = "AAP-Demo-DB-Tier"
    Role        = "db"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# Allocate and associate Elastic IP (EIP) to Web Tier
resource "aws_eip" "web_eip" {
  instance = aws_instance.web_tier.id
  domain   = "vpc"

  tags = {
    Name        = "AAP-Provisioned-Web-EIP"
    ManagedBy   = "Ansible-and-Terraform"
  }

  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.aap_job_launch.configure_weather_app]
    }
  }
}

# Launch the AAP Job Template once infrastructure & EIP are ready
action "aap_job_launch" "configure_weather_app" {
  config {
    job_template_id                     = var.aap_job_template_id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 1200

    extra_vars = jsonencode({
      "web_node_ip"                     : aws_eip.web_eip.public_ip,
      "web_node_dns"                    : aws_eip.web_eip.public_dns,
      "db_node_ip"                      : aws_instance.db_tier.public_ip,
      "db_private_ip"                   : aws_instance.db_tier.private_ip,
      "ansible_ssh_private_key_content" : "${trimspace(tls_private_key.demo_key.private_key_pem)}\n",
      "ansible_user"                    : "ec2-user",
      "weather_api_key"                 : var.weather_api_key,
      "environment"                     : "demo"
    })
  }
}

# ==========================================
# 4. OUTPUTS
# ==========================================

output "vpc_id" {
  value       = aws_vpc.weather_vpc.id
  description = "The ID of the newly created VPC"
}

output "web_public_ip" {
  value       = aws_eip.web_eip.public_ip
  description = "The public IP address of the Weather Web App"
}

output "web_public_dns" {
  value       = aws_eip.web_eip.public_dns
  description = "The AWS-provided public IPv4 DNS name assigned to the Web EIP"
}

output "db_private_ip" {
  value       = aws_instance.db_tier.private_ip
  description = "The internal private IP of the Database server"
}
