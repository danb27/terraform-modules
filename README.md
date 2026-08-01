# Terraform Modules

Reusable Terraform modules, intended to be consumed from other repositories by
git source.

Public so that Terraform can fetch modules in CI without a token — a private
module source needs a PAT or deploy key wired into every consuming workflow.
Nothing secret lives here; secrets belong in the consuming configuration.

## Modules

| Module | Provider | Notes |
| --- | --- | --- |
| [`github-oidc-role`](modules/github-oidc-role) | AWS | IAM role assumable by a named GitHub repository via OIDC, so CI needs no long-lived access keys. Takes the account's OIDC provider ARN as input rather than creating it — the provider is a per-account singleton. |
| [`cloudflare-gated-site`](modules/cloudflare-gated-site) | Cloudflare | Zone plus Zero Trust Access applications gating chosen paths behind an email allowlist. Interface is provisional — one consumer so far. |

## Usage

Pin to a tag. `?ref=main` means a push here can change what a downstream
`terraform apply` does, which is a bad property for infrastructure.

```hcl
module "ci_role" {
  source = "github.com/danb27/terraform-modules//modules/github-oidc-role?ref=v0.1.0"
  # ...
}
```

Each module's README documents its inputs and outputs.

## Versioning

Tagged `vMAJOR.MINOR.PATCH`. Below `v1.0.0`, treat minor bumps as potentially
breaking — the modules here are young and their interfaces are still moving.

## Local development

```bash
mise install
terraform fmt -recursive -check
actionlint
```

CI runs `fmt -check` and `validate` for every module on each pull request.
Modules are validated with `-backend=false`, so no credentials are involved.
