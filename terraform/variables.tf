variable "aws_region" {
  type        = string
  description = "The target AWS Region for deployment"
}

variable "vpc_name" {
  type        = string
  description = "The ID or Name Tag of the existing VPC"
}

variable "subnet_name" {
  type        = string
  description = "The ID or Name Tag of the target Subnet"
}

variable "security_group_name" {
  type        = string
  description = "The ID or Name Tag of the target Security Group"
}

variable "key_name" {
  type        = string
  description = "The AWS SSH Key Pair name for EC2 access"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "The AWS EC2 instance type size"
}

# --- AAP Provider Variables ---

variable "aap_hostname" {
  type        = string
  description = "The base URL of your AAP Controller instance"
}

variable "aap_token" {
  type        = string
  sensitive   = true
  description = "The API Token generated in AAP for the Terraform provider"
}

variable "aap_job_template_id" {
  type        = number
  description = "The numerical ID of the Child Template task"
}
