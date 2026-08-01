# github-oidc-role

An IAM role a GitHub Actions workflow can assume via OIDC, so CI needs no
long-lived AWS access keys. The trust policy is scoped to a single repository.

## Usage

```hcl
module "ci_role" {
  source = "github.com/danb27/terraform-modules//modules/github-oidc-role?ref=v0.2.0"

  name               = "my-project-github-actions"
  description        = "Terraform for danb27/my-project."
  github_owner       = "danb27"
  github_repo        = "my-project"
  github_owner_id    = 42096328   # gh api users/danb27 --jq .id
  github_repo_id     = 1319027887 # gh api repos/danb27/my-project --jq .id
  inline_policy_json = data.aws_iam_policy_document.ci.json
}
```

That's the whole thing — the module finds the account's OIDC provider itself.
See `variables.tf` for the full input list.

## Set the numeric IDs

`github_owner_id` and `github_repo_id` are optional, and you want them.

GitHub is migrating the OIDC `sub` claim from repository *names* to immutable
numeric identifiers:

```
repo:danb27/my-project:pull_request                      name-based
repo:danb27@42096328/my-project@1319027887:pull_request   immutable
```

Which form a token carries is decided GitHub-side. When it flips, a trust policy
matching only the other form stops matching and every workflow in the repository
fails with:

```
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

Nothing in that error points at the sub claim, and nothing in your configuration
changed — which makes it an unpleasant thing to debug. Supplying both IDs trusts
both forms, because policy condition values are OR'd, so the switch passes
unnoticed in either direction.

If you do hit it, CloudTrail has the claim that was actually presented:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --max-results 1 --query 'Events[0].CloudTrailEvent' --output text \
  | jq -r .userIdentity.userName
```

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
release produced a given role, and spot a consumer whose `?ref=` has drifted.

Those tags come from the shared [`_meta`](../_meta) module rather than being
written here, so the version string exists in one file for the whole repository.
release-please bumps it; it is not a hand-maintained constant, and CI fails if a
module stops using it.

## Trust boundary

The role trusts every workflow context in the named repository. A pull request
from a fork does **not** receive the base repository's OIDC subject, so this
does not expose the role to outside contributors — but it does expose it to any
branch someone with write access can push.

To narrow it to a single branch or a gated environment, edit the `sub`
condition in `main.tf`. It is deliberately not an input: nothing needed one yet,
and a knob nobody sets is a knob nobody tests.
