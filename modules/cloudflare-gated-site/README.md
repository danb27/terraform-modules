# cloudflare-gated-site

A Cloudflare zone plus Zero Trust Access applications that gate one or more
paths behind an email allowlist.

Requests that fail the policy are rejected at Cloudflare's edge and never reach
the origin, so the site behind this carries no auth code: no login form, no
session handling, no password storage, nothing to keep patched.

> **Interface stability:** this module currently has one consumer. Expect the
> variables to shift once a second site exercises it.

## Usage

```hcl
module "site" {
  source = "github.com/danb27/terraform-modules//modules/cloudflare-gated-site?ref=v0.1.0"

  account_id  = var.cloudflare_account_id
  domain_name = "example.com"

  protected_paths = ["/private", "/admin"]
  allowed_emails  = var.allowed_emails
}
```

Point the registrar at the zone's nameservers to finish the setup:

```hcl
resource "aws_route53domains_registered_domain" "this" {
  domain_name = "example.com"

  dynamic "name_server" {
    for_each = module.site.name_servers
    content {
      name = name_server.value
    }
  }
}
```

Registrar delegation is deliberately left to the caller — it is an AWS concern,
and keeping it out means this module needs only the Cloudflare provider.

## What it does not do

- **Serve anything.** Bring your own origin: a Worker, Pages, or any host. This
  manages the zone and the access policy, not the content.
- **Configure an identity provider.** With none set on the account, Access
  emails a one-time PIN, which needs no setup. Add Google, GitHub, or a SAML IdP
  at the account level and the same policy starts accepting those logins.
- **Cover subdomains.** `protected_paths` guards paths on the apex only. A
  `www` host serving the same content would be ungated unless you add an Access
  application for it too.

## Identity is enforced, not exposed

Access decides *whether* a request gets through. It does not tell your origin
*who* made it unless the origin reads the headers Access forwards:
a signed JWT and `Cf-Access-Authenticated-User-Email`.

Static assets alone cannot read those. Serving identity-aware content means
putting a Worker script in front. If the content is genuinely sensitive, verify
the JWT rather than trusting the header — the header is trustworthy only for as
long as Cloudflare is the sole path to your origin.

## Sensitive values reach state

`allowed_emails` is marked sensitive, which keeps it out of plan output and CI
logs. It does **not** keep it out of Terraform state, where variable values are
stored in plaintext. Use a private, encrypted backend.

<!-- BEGIN_TF_DOCS -->

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | :---: |
| `account_id` | Cloudflare account ID. | `string` | — | yes |
| `domain_name` | Apex domain for the site. | `string` | — | yes |
| `create_zone` | Whether to create the zone. | `bool` | `true` | no |
| `zone_id` | Existing zone, when `create_zone` is false. | `string` | `null` | no |
| `protected_paths` | Paths to put behind Access. | `list(string)` | `["/private"]` | no |
| `allowed_emails` | Exact addresses allowed through. | `list(string)` | `[]` | no |
| `allowed_email_domains` | Whole domains allowed through. | `list(string)` | `[]` | no |
| `session_duration` | Login validity before re-authentication. | `string` | `"24h"` | no |
| `policy_name` | Access policy name. Defaults to the domain. | `string` | `null` | no |

## Outputs

| Name | Description |
| --- | --- |
| `zone_id` | ID of the zone the site is served from. |
| `name_servers` | Nameservers to point the registrar at. |
| `zone_status` | `active` only once delegation has propagated. |
| `policy_id` | ID of the shared Access policy. |
| `protected_urls` | URLs now behind Access. |

<!-- END_TF_DOCS -->
