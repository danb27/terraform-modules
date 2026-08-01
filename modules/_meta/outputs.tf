output "tags" {
  description = <<-EOT
    Tags every module applies to every resource it creates.

    Tagging with the module and the exact released version means you can tell,
    from the console alone, which release produced a given resource - and spot a
    consumer whose `?ref=` has drifted without having to reason about it.
  EOT
  value = {
    terraform      = "true"
    module         = "danb27/terraform-modules//modules/${var.module_name}"
    module_version = local.module_version
  }
}

output "module_version" {
  description = "The released version of this repository."
  value       = local.module_version
}
