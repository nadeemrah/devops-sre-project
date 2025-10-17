output "vpc_id" {
  value =  module.vpc.vpc_id
}

output "private_subnets" {
  value =  module.vpc.private_subnets
}

output "public_subnets" {
  value =  module.vpc.public_subnets
}

output "tags" {
  value =  local.tags
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "The ID of the EKS cluster. Note: currently a value is returned only for local EKS clusters created on Outposts"
  value       = module.eks.cluster_id
}



output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_dualstack_oidc_issuer_url" {
  description = "Dual-stack compatible URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_dualstack_oidc_issuer_url
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks.cluster_platform_version
}



output "access_entries" {
  description = "Map of access entries created and their attributes"
  value       = module.eks.access_entries
}


output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}

output "kubeconfig_file" {
  value = local_file.kubeconfig.filename
}


output "fluentd_iam_role_arn" {
  value = aws_iam_role.fluentd_irsa.arn
}
