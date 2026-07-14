variable "aap_hostname" {
  type        = string
  description = "The base URL of your Ansible Automation Platform Controller instance"
}

variable "aap_token" {
  type        = string
  sensitive   = true
  description = "Application Token generated in AAP for Terraform authentication"
}

variable "aap_job_template_id" {
  type        = number
  description = "The numerical ID of the Job Template in AAP tasked with configuration"
}