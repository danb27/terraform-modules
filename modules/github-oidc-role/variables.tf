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

    Leave unset in almost every case - the module looks the provider up itself.

    Pass it explicitly only from the account-level configuration that *creates*
    the provider, where a data source would find nothing on the first apply.
  EOT
  type        = string
  default     = null
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
