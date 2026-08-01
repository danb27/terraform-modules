variable "name" {
  description = "Name of the IAM role."
  type        = string
}

variable "description" {
  description = "Role description."
  type        = string
  default     = "Assumed by GitHub Actions via OIDC."
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
  description = "Repository allowed to assume this role."
  type        = string
}

variable "allowed_claims" {
  description = <<-EOT
    Which workflow contexts may assume the role, as the portion of the OIDC
    subject that follows `repo:<owner>/<repo>:`.

    Defaults to every context in the repository. Narrow it to restrict which
    branches or environments can assume the role, for example:

      ["ref:refs/heads/main"]        only the default branch
      ["environment:production"]     only jobs targeting that environment
      ["pull_request"]               only pull request events

    Wildcards are permitted; the condition uses StringLike.
  EOT
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.allowed_claims) > 0
    error_message = "At least one claim is required, otherwise nothing could assume the role."
  }
}

variable "inline_policy_json" {
  description = "Optional IAM policy document JSON attached inline. Use aws_iam_policy_document to build it."
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "Optional managed policies to attach."
  type        = list(string)
  default     = []
}

variable "max_session_duration" {
  description = "Maximum session length in seconds. The default is the AWS minimum, which is plenty for CI."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Additional tags for the role."
  type        = map(string)
  default     = {}
}
