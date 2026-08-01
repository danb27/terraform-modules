# Shared metadata for every module in this repository.
#
# Exists so the released version lives in exactly one file. Each module calls
# this and tags its resources with the result, which means a release bumps one
# string rather than one per module - and no module can quietly drift to
# reporting a version it was not built from.
#
# Consumed by relative path (`source = "../_meta"`). Terraform clones the whole
# repository for a git source, so that resolves for external callers too.

locals {
  # Bumped by release-please; see extra-files in release-please-config.json.
  # This is the only place the version is written. Do not edit by hand.
  module_version = "0.0.1" # x-release-please-version
}
