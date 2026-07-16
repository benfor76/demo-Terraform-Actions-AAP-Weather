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

# 1. Dynamic VPC Discovery
data "aws_vpc" "selected" {
  id = startswith(var.vpc_name, "vpc-") ? var.vpc_name : null

  dynamic "filter" {
    for_each = startswith(var.vpc_name, "vpc-") ? [] : [1]
    content {
      name   = "tag:Name"
      values = [var.vpc_name]
    }
  }
}

# 2. Dynamic Subnet Discovery
data "aws_subnet" "selected" {
  id     = startswith(var.subnet_name, "subnet-") ? var.subnet_name : null
  vpc_id = data.aws_vpc.selected.id

  dynamic "filter" {
    for_each = startswith(var.subnet_name, "subnet-") ? [] : [1]
    content {
      name   = "tag:Name"
      values = [var.subnet_name]
    }
  }
}

# 3. Dynamic Security Group Discovery
data "aws_security_group" "selected" {
  id     = startswith(var.security_group_name, "sg-") ? var.security_group_name : null
  vpc_id = data.aws_vpc.selected.id

  dynamic "filter" {
    for_each = startswith(var.security_group_name, "sg-") ? [] : [1]
    content {
      name   = "group-name"
      values = [var.security_group_name]
    }
  }
}

# 4. Discover the latest official RHEL 9 AMI
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

# 5a. Provision Instance A: Web/App Tier
resource "aws_instance" "web_tier" {
  ami                    = data.aws_ami.rhel9.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [data.aws_security_group.selected.id]
  key_name               = var.key_name

  tags = {
    Name        = "AAP-Demo-Web-Tier"
    Role        = "web"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# 5b. Provision Instance B: Database Tier
resource "aws_instance" "db_tier" {
  ami                    = data.aws_ami.rhel9.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [data.aws_security_group.selected.id]
  key_name               = var.key_name
  associate_public_ip_address = true # <--- ADD THIS LINE

  tags = {
    Name        = "AAP-Demo-DB-Tier"
    Role        = "db"
    ManagedBy   = "Ansible-and-Terraform"
    Environment = "Demo"
  }
}

# 6. Allocate and associate an Elastic IP (EIP) only to the Web/App Tier
resource "aws_eip" "web_eip" {
  instance = aws_instance.web_tier.id
  domain   = "vpc"

  tags = {
    Name        = "AAP-Provisioned-Web-EIP"
    ManagedBy   = "Ansible-and-Terraform"
  }

  # --- FIXED: The lifecycle block is now safely nested inside the aws_eip resource ---
  lifecycle {
    action_trigger {
      events  = [after_create] # FIXED: Wrapped event keyword in quotes
      actions = [action.aap_job_launch.configure_weather_app]
    }
  }
}

# 7. Launch the AAP Job Template once infrastructure is ready
action "aap_job_launch" "configure_weather_app" {
  config {
    job_template_id                     = var.aap_job_template_id
    wait_for_completion                 = true 
    wait_for_completion_timeout_seconds = 1200

    extra_vars = jsonencode({
      "web_node_ip"  : aws_eip.web_eip.public_ip,
      "web_node_dns" : aws_eip.web_eip.public_dns,   
      "db_node_ip"   : aws_instance.db_tier.private_ip,
      "weather_api_key" : var.weather_api_key, # <-- ADD THIS LINE
      "environment"  : "demo"
    })
  }
}

# --- Outputs for Visibility ---

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