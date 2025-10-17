################################################################################
# IAM role for argocd for Pod idnetity 
################################################################################

resource "aws_iam_role" "argocd_role" {
  name        = "argocd-policy-${var.cluster_name}"
  description = "pod identity policy for ArgoCD (example: read access to SSM & ECR)."

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        Resource = "*"
      }
    ]
  })
}

################################################################################
# IAM role for prometheus for Pod idnetity 
################################################################################

resource "aws_iam_role" "prometheus_role" {
  name        = "prometheus-policy-${var.cluster_name}"
  description = "pod identity policy for Prometheus (example: read CloudWatch metrics)."

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

