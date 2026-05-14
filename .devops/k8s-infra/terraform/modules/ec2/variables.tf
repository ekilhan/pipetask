variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "user_data" {
  description = "User data script for instance initialization"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "NodeName" {
  description = "Node name tag"
  type        = string
}

variable "Project" {
  description = "Project name tag"
  type        = string
}

variable "NodeRole" {
  description = "Node role (master/worker)"
  type        = string
}

variable "NodeId" {
  description = "Node ID"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "security_group_ids" {
  description = "Security group ID"
  type        = string
}
