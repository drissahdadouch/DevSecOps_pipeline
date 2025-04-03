provider "aws" {
  region = "us-east-1"  # Change as needed
}

# 🔹 Create VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  
  tags = { Name = "eks-vpc" }
}

# 🔹 Create Public Subnets
resource "aws_subnet" "eks_subnet_1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "eks-subnet-1" }
}

resource "aws_subnet" "eks_subnet_2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = { Name = "eks-subnet-2" }
}

# 🔹 Create Internet Gateway
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags   = { Name = "eks-igw" }
}

# 🔹 Create Public Route Table
resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = { Name = "eks-public-route-table" }
}

# 🔹 Associate Route Table with Subnets
resource "aws_route_table_association" "subnet_association_1" {
  subnet_id      = aws_subnet.eks_subnet_1.id
  route_table_id = aws_route_table.eks_public_rt.id
}

resource "aws_route_table_association" "subnet_association_2" {
  subnet_id      = aws_subnet.eks_subnet_2.id
  route_table_id = aws_route_table.eks_public_rt.id
}

# 🔹 IAM Role for EKS Cluster
resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# 🔹 Attach IAM Policies to EKS Role
resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# 🔹 Create EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.eks_subnet_1.id, aws_subnet.eks_subnet_2.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_policy_attachment]
}

# 🔹 IAM Role for Worker Nodes
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# 🔹 Attach IAM Policies to Worker Nodes Role
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 🔹 Create EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.eks_subnet_1.id, aws_subnet.eks_subnet_2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_policy
  ]
}

# 🔹 Outputs
output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}
