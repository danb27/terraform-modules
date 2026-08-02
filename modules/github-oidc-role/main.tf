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

    # The actual boundary: any workflow context in this one repository.
    #
    # This deliberately matches the "repository" claim rather than picking
    # apart "sub". GitHub is migrating sub to a format embedding numeric owner
    # and repository IDs:
    #
    #   repo:danb27/aws-infra:pull_request                     (name-based)
    #   repo:danb27@42096328/aws-infra@1319056665:pull_request (immutable)
    #
    # A policy matching only one form stops matching when a repository moves to
    # the other, and every workflow fails AccessDenied on
    # sts:AssumeRoleWithWebIdentity with nothing in the error naming the claim.
    # The "repository" claim is "owner/repo" under both formats, so matching it
    # sidesteps the migration entirely - and matches exactly, with no wildcard.
    #
    # To restrict further, add a condition on another claim rather than
    # narrowing this one: ":ref" for a single branch, ":environment" for a
    # gated environment. AWS exposes actor, actor_id, job_workflow_ref,
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
