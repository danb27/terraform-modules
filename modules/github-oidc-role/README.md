# github-oidc-role

An IAM role a GitHub Actions workflow can assume via OIDC, so CI needs no
long-lived AWS access keys. The trust policy is scoped to a single repository.

## Usage

```hcl
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "ci_role" {
  source = "github.com/danb27/terraform-modules//modules/github-oidc-role?ref=v0.1.0"

  name               = "my-project-github-actions"
  description        = "Terraform for danb27/my-project."
  oidc_provider_arn  = data.aws_iam_openid_connect_provider.github.arn
  github_owner       = "danb27"
  github_repo        = "my-project"
  inline_policy_json = data.aws_iam_policy_document.ci.json
}
```

Then in the workflow:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v5
    with:
      role-to-assume: ${{ secrets.AWS_ROLE }}
      aws-region: us-east-1
```

See `variables.tf` for the full input list.

## The OIDC provider is a per-account singleton

An AWS account can hold exactly one IAM OIDC provider for
`token.actions.githubusercontent.com`. This module deliberately does **not**
create it — if two projects each created their own, the second apply would fail
with `EntityAlreadyExists`, and destroying either would break every other
repository relying on it.

Create it once in an account-level configuration and pass its ARN in. That
config can pass the resource directly in the same apply that creates it;
everyone else uses a data source.

## Trust boundary

The role trusts every workflow context in the named repository. A pull request
from a fork does **not** receive the base repository's OIDC subject, so this
does not expose the role to outside contributors — but it does expose it to any
branch someone with write access can push.

To narrow it to a single branch or a gated environment, edit the `sub`
condition in `main.tf`. It is deliberately not an input: nothing needed one yet,
and a knob nobody sets is a knob nobody tests.
