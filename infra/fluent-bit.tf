data "aws_iam_openid_connect_provider" "eks" {
  arn = module.eks.oidc_provider_arn
}

# Fluentd IAM role for IRSA
resource "aws_iam_role" "fluentd_irsa" {
  name = "${var.cluster_name}-fluentd-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:logging:fluentd"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "fluentd_cloudwatch_policy" {
  name = "${var.cluster_name}-fluentd-cloudwatch-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fluentd_attach" {
  role       = aws_iam_role.fluentd_irsa.name
  policy_arn = aws_iam_policy.fluentd_cloudwatch_policy.arn
}
