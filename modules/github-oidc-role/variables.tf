variable "name" {
  description = "Name of the IAM role."
  type        = string
}

variable "description" {
  description = "Role description."
  type        = string
}

variable "oidc_provider_arn" {
  description = <<-EOT
    ARN of the account's GitHub Actions OIDC provider.

    Taken as an input rather than looked up, because the account-level config
    that creates the provider needs a role in the same apply - a data source
    would not resolve. Consumers that are not creating the provider can pass
    data.aws_iam_openid_connect_provider.github.arn.
  EOT
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organisation that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "Repository allowed to assume this role. Every workflow context in it is trusted."
  type        = string
}

variable "inline_policy_json" {
  description = "IAM policy document JSON attached inline. Build it with aws_iam_policy_document."
  type        = string
}

variable "managed_policy_arns" {
  description = "Managed policies to attach, in addition to the inline one."
  type        = list(string)
  default     = []
}
