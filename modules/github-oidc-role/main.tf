# Shared tags and the released version. Every module in this repository does
# this, so the version is written in exactly one file.
module "meta" {
  source      = "../_meta"
  module_name = "github-oidc-role"
}

locals {
  oidc_provider_arn = coalesce(
    var.oidc_provider_arn,
    one(data.aws_iam_openid_connect_provider.github[*].arn),
  )
}

# Skipped when the caller supplies the ARN, which is what the configuration
# creating the provider has to do - on its first apply there is nothing here
# for a data source to find.
data "aws_iam_openid_connect_provider" "github" {
  count = var.oidc_provider_arn == null ? 1 : 0

  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    # Without this, a token minted for any audience would be accepted.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Required, and not by us. IAM classifies token.actions.githubusercontent.com
    # as a *shared* OIDC provider - every GitHub customer federates through the
    # same issuer URL, so the issuer alone proves nothing about tenancy. For
    # those providers IAM insists the trust policy constrain a specific claim,
    # and for GitHub that claim is "sub". Omit this and CreateRole and
    # UpdateAssumeRolePolicy both fail:
    #
    #   MalformedPolicyDocument: Trust policy with trusted principal
    #   ...:oidc-provider/token.actions.githubusercontent.com must evaluate,
    #   using StringEquals, StringLike or StringEqualsIgnoreCase,
    #   token.actions.githubusercontent.com:sub or
    #   token.actions.githubusercontent.com:job_workflow_ref which is not
    #   scoped to all.
    #
    # No other claim substitutes, however precisely it is matched.
    #
    # Both forms are listed because GitHub is migrating sub to a format
    # embedding numeric owner and repository IDs:
    #
    #   repo:danb27/aws-infra:pull_request                     (name-based)
    #   repo:danb27@42096328/aws-infra@1319056665:pull_request (immutable)
    #
    # Values are OR'd, so a repository switching between them is a non-event.
    # The IDs are wildcarded rather than taken as inputs - which would be too
    # loose on its own, and is not on its own. See the condition below.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repo}:*",
        "repo:${var.github_owner}@*/${var.github_repo}@*:*",
      ]
    }

    # The actual boundary: any workflow context in this one repository.
    #
    # Separate condition blocks are AND'd, so this exact match is what bounds
    # trust and the wildcards above only satisfy the IAM requirement. That
    # matters - a sub built to slip past those wildcards (an environment name
    # containing "/", "@" and ":" in another repository under this owner) still
    # has to present repository == "owner/repo", which it cannot.
    #
    # Unlike sub, this claim is "owner/repo" under both formats, so it needs no
    # wildcard and is unaffected by the migration.
    #
    # To restrict further, add a condition on another claim rather than
    # narrowing either of these: ":ref" for a single branch, ":environment" for
    # a gated environment. AWS exposes actor, actor_id, job_workflow_ref,
    # repository, repository_id, repository_owner_id, workflow, ref,
    # environment and enterprise_id.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository"
      values   = ["${var.github_owner}/${var.github_repo}"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  description        = var.description
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = module.meta.tags
}

resource "aws_iam_role_policy" "inline" {
  name   = "inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
