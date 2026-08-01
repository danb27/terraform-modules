locals {
  zone_id     = var.create_zone ? cloudflare_zone.this[0].id : var.zone_id
  policy_name = coalesce(var.policy_name, var.domain_name)

  # Include rules are OR'd by Access: a visitor needs to match only one.
  include_rules = concat(
    [for address in var.allowed_emails : { email = { email = address } }],
    [for domain in var.allowed_email_domains : { email_domain = { domain = domain } }],
  )
}

resource "cloudflare_zone" "this" {
  count = var.create_zone ? 1 : 0

  account = {
    id = var.account_id
  }
  name = var.domain_name
  type = "full"
}

# A single policy shared by every protected path. Changing who has access is
# one edit here rather than one per application.
resource "cloudflare_zero_trust_access_policy" "allowlist" {
  count = length(var.protected_paths) > 0 ? 1 : 0

  account_id = var.account_id
  name       = "${local.policy_name} allowlist"
  decision   = "allow"
  include    = local.include_rules
}

# Requests failing the policy are rejected at Cloudflare's edge and never reach
# the origin, so the site behind this needs no auth code of its own.
#
# With no identity provider configured on the account, Access falls back to
# emailing a one-time PIN, which is why this works with no IdP setup.
resource "cloudflare_zero_trust_access_application" "protected" {
  for_each = toset(var.protected_paths)

  zone_id          = local.zone_id
  name             = "${var.domain_name}${each.value}"
  domain           = "${var.domain_name}${each.value}"
  type             = "self_hosted"
  session_duration = var.session_duration

  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  http_only_cookie_attribute = true
  same_site_cookie_attribute = "lax"

  policies = [
    {
      id         = one(cloudflare_zero_trust_access_policy.allowlist).id
      precedence = 1
    }
  ]
}
