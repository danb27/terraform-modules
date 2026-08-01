# github-oidc-role

An IAM role a GitHub Actions workflow can assume via OIDC, so CI needs no
long-lived AWS access keys.

The role's trust policy is scoped to a single repository, and optionally to
specific branches or environments within it.

## Usage

```hcl
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "ci" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::my-bucket/*"]
  }
}

module "ci_role" {
  source = "github.com/danb27/terraform-modules//modules/github-oidc-role?ref=v0.1.0"

  name              = "my-project-github-actions"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  github_owner      = "danb27"
  github_repo       = "my-project"

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
      role-to-assume: ${{ vars.AWS_ROLE }}
      aws-region: us-east-1
```

## The OIDC provider is a per-account singleton

An AWS account can hold exactly one IAM OIDC provider for
`token.actions.githubusercontent.com`. This module deliberately does **not**
create it — if two projects each created their own, the second apply would fail
with `EntityAlreadyExists`, and destroying either project would break every
other repository relying on it.

Create the provider once in an account-level configuration and pass its ARN in.
That config can pass the resource directly (`aws_iam_openid_connect_provider.github.arn`)
in the same apply that creates it; everyone else uses a data source.

## Narrowing the trust boundary

`allowed_claims` is the part of the OIDC subject after `repo:<owner>/<repo>:`.
The default, `["*"]`, trusts every workflow context in the repository — fine for
a repo where every branch is yours, worth narrowing when it isn't:

| Value | Meaning |
| --- | --- |
| `["*"]` | Any branch, tag, PR, or environment (default) |
| `["ref:refs/heads/main"]` | Only the default branch |
| `["environment:production"]` | Only jobs targeting that environment |
| `["pull_request"]` | Only pull request events |

A pull request from a fork does **not** receive the base repository's subject,
so `["*"]` does not expose the role to outside contributors. It does expose it
to any branch someone with write access can push.

<!-- BEGIN_TF_DOCS -->

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | :---: |
| `name` | Name of the IAM role. | `string` | — | yes |
| `oidc_provider_arn` | ARN of the account's GitHub Actions OIDC provider. | `string` | — | yes |
| `github_owner` | GitHub user or organisation that owns the repository. | `string` | — | yes |
| `github_repo` | Repository allowed to assume this role. | `string` | — | yes |
| `allowed_claims` | Workflow contexts permitted to assume the role. | `list(string)` | `["*"]` | no |
| `inline_policy_json` | IAM policy document JSON attached inline. | `string` | `null` | no |
| `managed_policy_arns` | Managed policies to attach. | `list(string)` | `[]` | no |
| `max_session_duration` | Maximum session length, in seconds. | `number` | `3600` | no |
| `description` | Role description. | `string` | `"Assumed by GitHub Actions via OIDC."` | no |
| `tags` | Additional tags for the role. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| --- | --- |
| `role_arn` | ARN to set as `AWS_ROLE` in the consuming repository. |
| `role_name` | Name of the created role. |
| `trusted_subjects` | OIDC subjects permitted to assume the role. |

<!-- END_TF_DOCS -->
