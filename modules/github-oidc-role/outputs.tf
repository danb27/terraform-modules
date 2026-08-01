output "role_arn" {
  description = "Set this as the AWS_ROLE secret in the consuming repository."
  value       = aws_iam_role.this.arn
}
