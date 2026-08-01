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

    # The actual boundary: any workflow context in this one repository. Narrow
    # the suffix to restrict it further - "ref:refs/heads/main" for the default
    # branch only, "environment:production" for a gated environment.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:*"]
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
