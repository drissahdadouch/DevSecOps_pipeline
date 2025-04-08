variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  default     = "my-eks-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_1_cidr" {
  description = "CIDR block for the first subnet"
  default     = "10.0.1.0/24"
}

variable "subnet_2_cidr" {
  description = "CIDR block for the second subnet"
  default     = "10.0.2.0/24"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  default     = 3
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  default     = 2
}
