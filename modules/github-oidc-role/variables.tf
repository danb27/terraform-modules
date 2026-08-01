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

variable "github_owner_id" {
  description = <<-EOT
    Numeric ID of the GitHub owner: `gh api users/OWNER --jq .id`.

    Set this together with github_repo_id. GitHub is migrating the OIDC sub
    claim to immutable identifiers built from these numbers rather than names;
    supplying them makes the role trust both forms, so the migration is a
    non-event. Leave both unset and only the name-based form is trusted.
  EOT
  type        = number
  default     = null

  validation {
    condition     = (var.github_owner_id == null) == (var.github_repo_id == null)
    error_message = "Set github_owner_id and github_repo_id together, or neither - one alone cannot build the immutable sub claim."
  }
}

variable "github_repo_id" {
  description = "Numeric ID of the repository: `gh api repos/OWNER/REPO --jq .id`. See github_owner_id."
  type        = number
  default     = null
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
