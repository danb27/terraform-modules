# github-oidc-role

An IAM role a GitHub Actions workflow can assume via OIDC, so CI needs no
long-lived AWS access keys. The trust policy is scoped to a single repository.

## Usage

```hcl
module "ci_role" {
  source = "github.com/danb27/terraform-modules//modules/github-oidc-role?ref=v0.1.0"

  name               = "my-project-github-actions"
  description        = "Terraform for danb27/my-project."
  github_owner       = "danb27"
  github_repo        = "my-project"
  inline_policy_json = data.aws_iam_policy_document.ci.json
}
```

That's the whole thing — the module finds the account's OIDC provider itself.
See `variables.tf` for the full input list.

## Wiring up the workflow

Two pieces are needed, and neither is a complete workflow on its own. Grant the
job permission to mint an OIDC token:

```yaml
permissions:
  id-token: write # required, or the credentials step cannot get a token
  contents: read
```

Then exchange that token for AWS credentials, **before** whatever steps actually
need AWS. Every later step in the same job inherits them:

```yaml
steps:
  - uses: actions/checkout@v7

  - uses: aws-actions/configure-aws-credentials@v6
    with:
      role-to-assume: ${{ secrets.AWS_ROLE }}
      aws-region: us-west-2

  # ... your terraform / aws-cli / whatever steps go here, and are now
  # authenticated. No access keys anywhere.
```

Set `AWS_ROLE` from this module's `role_arn` output.

## The OIDC provider is a per-account singleton

An AWS account can hold exactly one IAM OIDC provider for
`token.actions.githubusercontent.com`. This module deliberately does **not**
create it — if two projects each created their own, the second apply would fail
with `EntityAlreadyExists`, and destroying either would break every other
repository relying on it.

Create it once in an account-level configuration. Everything else finds it by
lookup, which is why `oidc_provider_arn` is optional and you can normally forget
it exists.

The one exception is that account-level configuration itself: it creates the
provider *and* wants a role in the same apply, and on the first run a data
source would find nothing. That config passes `oidc_provider_arn` explicitly.

## Tagging

Every resource is tagged `terraform = "true"`, plus the module source and the
exact released version it came from — so you can tell from the console which
release produced a given role. The version string is bumped by release-please
on each release; it is not a hand-maintained constant.

## Trust boundary

The role trusts every workflow context in the named repository. A pull request
from a fork does **not** receive the base repository's OIDC subject, so this
does not expose the role to outside contributors — but it does expose it to any
branch someone with write access can push.

To narrow it to a single branch or a gated environment, edit the `sub`
condition in `main.tf`. It is deliberately not an input: nothing needed one yet,
and a knob nobody sets is a knob nobody tests.
