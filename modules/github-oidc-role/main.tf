locals {
  # Bumped automatically by release-please; see extra-files in
  # release-please-config.json. Do not edit by hand.
  module_version = "0.0.1" # x-release-please-version

  module_source = "danb27/terraform-modules//modules/github-oidc-role"

  # Tagging every resource with the module and the exact version it came from
  # means you can tell, from the console alone, which release produced a role.
  tags = {
    terraform      = "true"
    module         = local.module_source
    module_version = local.module_version
  }

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
  tags               = local.tags
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
