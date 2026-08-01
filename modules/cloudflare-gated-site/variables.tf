variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "domain_name" {
  description = "Apex domain for the site."
  type        = string
}

variable "create_zone" {
  description = "Whether to create the Cloudflare zone. Set false and pass zone_id to attach to an existing one."
  type        = bool
  default     = true
}

variable "zone_id" {
  description = "Existing zone to use when create_zone is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_zone || var.zone_id != null
    error_message = "zone_id is required when create_zone is false."
  }
}

variable "protected_paths" {
  description = <<-EOT
    Paths to put behind Access, each guarding that prefix and everything under it.

    One Access application is created per path, all sharing a single policy.
    An empty list creates no applications, which leaves the whole site public.
  EOT
  type        = list(string)
  default     = ["/private"]

  validation {
    condition     = alltrue([for p in var.protected_paths : startswith(p, "/")])
    error_message = "Each protected path must begin with a forward slash."
  }
}

variable "allowed_emails" {
  description = <<-EOT
    Exact email addresses allowed through Access.

    Sensitive, which keeps the list out of plan output - but NOT out of
    Terraform state, where variable values are stored in plaintext. Keep state
    in a private, encrypted backend.
  EOT
  type        = list(string)
  default     = []
  sensitive   = true

  # A protected path with no include rules would match nobody and lock everyone
  # out, including whoever is running the apply.
  validation {
    condition = (
      length(var.protected_paths) == 0 ||
      length(var.allowed_emails) + length(var.allowed_email_domains) > 0
    )
    error_message = "Protecting a path requires at least one entry in allowed_emails or allowed_email_domains."
  }
}

variable "allowed_email_domains" {
  description = "Whole email domains allowed through Access, for example \"example.com\". Combined with allowed_emails using OR."
  type        = list(string)
  default     = []
}

variable "session_duration" {
  description = "How long a successful login stays valid before re-authentication."
  type        = string
  default     = "24h"
}

variable "policy_name" {
  description = "Name of the Access policy. Defaults to the domain name."
  type        = string
  default     = null
}
