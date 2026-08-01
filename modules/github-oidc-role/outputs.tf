output "role_arn" {
  description = "Set this as the AWS_ROLE secret or variable in the consuming repository."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the created role."
  value       = aws_iam_role.this.name
}

output "trusted_subjects" {
  description = "The OIDC subjects permitted to assume the role. Useful for confirming the boundary is what you intended."
  value       = local.subjects
}
