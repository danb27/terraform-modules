# Terraform Modules

Reusable Terraform modules, consumed from other repositories by git source.

Public so that Terraform can fetch modules in CI without a token — a private
module source needs a PAT or deploy key wired into every consuming workflow.
Nothing secret lives here; secrets belong in the consuming configuration.

## Modules

| Module | Provider | Notes |
| --- | --- | --- |
| [`github-oidc-role`](modules/github-oidc-role) | AWS | IAM role assumable by a named GitHub repository via OIDC. Takes the account's OIDC provider ARN as input rather than creating it — the provider is a per-account singleton. |

Each module's `variables.tf` is the source of truth for its inputs.

## What isn't here

A module gets extracted when it has a second real consumer, not before. Cloudflare
zone and Access configuration lives inline in `danb27/daninthreecolors` for that
reason — one site, so an interface designed against a single caller would be
guesswork.

## Usage

Pin to a tag. `?ref=main` means a push here can change what a downstream
`terraform apply` does, which is a bad property for infrastructure.

```hcl
module "ci_role" {
  source = "github.com/danb27/terraform-modules//modules/github-oidc-role?ref=v0.1.0"
  # ...
}
```

## Versioning

Automated by release-please from conventional commits: merging to `main` opens a
release PR, and merging that tags `vMAJOR.MINOR.PATCH` and publishes the release.
Below `v1.0.0`, treat minor bumps as potentially breaking.

CI does not run on the release PR — PRs opened with the default `GITHUB_TOKEN`
don't trigger `on: pull_request` workflows. That PR only touches the changelog
and version file.

## Local development

```bash
mise install
terraform fmt -recursive -check
actionlint
```
