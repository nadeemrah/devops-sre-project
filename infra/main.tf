################################################################################
# VPC creation with HA
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.4.0" 

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, length(var.private_subnets))
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true   

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

################################################################################
# EKS Creation in HA
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name            = var.cluster_name
  kubernetes_version = "1.32" 

  addons = {
    coredns                = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy             = {}
    vpc-cni                = {
      before_compute = true
    }
  }

  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  endpoint_public_access  = false
  endpoint_private_access = true

  eks_managed_node_groups = {
    system = {
      desired_size = 2
      max_size     = 3
      min_size     = 1
      instance_types   = ["t3.medium"] 
      subnet_ids          = module.vpc.private_subnets
      labels = {
        node-role = "system"
      }
      capacity_type = "ON_DEMAND"
    }

    app_spot = {
      desired_capacity = 2
      max_capacity     = 4
      min_capacity     = 1
      instance_types   = ["m6i.xlarge","m5.large"] 
      subnets          = module.vpc.private_subnets
      labels = {
        node-role = "app"
      }
      capacity_type = "SPOT"
    }
  }

  tags = local.tags
}

################################################################################
# NACL for Private subnets
################################################################################

resource "aws_network_acl" "private_acl" {
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  tags = merge(local.tags, { Name = "private-acl" })
}

resource "aws_network_acl_rule" "private_allow_ephemeral" {
  network_acl_id = aws_network_acl.private_acl.id
  rule_number    = 100
  protocol       = "6" 
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_deny_all_inbound" {
  network_acl_id = aws_network_acl.private_acl.id
  rule_number    = 32767
  protocol       = "-1"
  rule_action    = "deny"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}


################################################################################
# Pod Identity Association for Argocd and Prometheus 
################################################################################

resource "aws_eks_pod_identity_association" "argocd" {
  region = var.region

  cluster_name    = var.cluster_name
  namespace       = argocd
  service_account = argocd
  role_arn        = aws_iam_role.argocd_role.arn
  tags = local.tags
}

resource "aws_eks_pod_identity_association" "prometheus" {
  region = var.region

  cluster_name    = var.cluster_name
  namespace       = monitoring
  service_account = monitoring
  role_arn        = aws_iam_role.prometheus_role.arn

  tags = local.tags
}
