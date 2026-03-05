variable "instance_type" {
  type        = string
  default     = "c7i-flex.large"
  description = "EC2 instance type for the Jenkins server."
}

variable "key_name" {
  type        = string
  description = "my-key"
}

variable "private_key_path" {
  type        = string
  description = ""
}

variable "my_ip" {
  type        = string
  description = "Your public IP address (in CIDR form) to restrict SSH access."
}

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"    # optional, can be omitted if you always
                               # supply it via tfvars
}
