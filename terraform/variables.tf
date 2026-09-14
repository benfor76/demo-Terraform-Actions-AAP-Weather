variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "The target AWS Region for deployment"
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

variable "weather_api_key" {
  type        = string
  sensitive   = true
  description = "The live OpenWeatherMap API key"
}
