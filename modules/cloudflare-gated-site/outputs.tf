output "zone_id" {
  description = "ID of the zone the site is served from."
  value       = local.zone_id
}

output "name_servers" {
  description = "Nameservers Cloudflare assigned to the zone. Point the registrar at these. Null when create_zone is false."
  value       = var.create_zone ? cloudflare_zone.this[0].name_servers : null
}

output "zone_status" {
  description = "Cloudflare reports 'active' only once nameserver delegation has propagated. Null when create_zone is false."
  value       = var.create_zone ? cloudflare_zone.this[0].status : null
}

output "policy_id" {
  description = "ID of the shared Access policy, or null when nothing is protected."
  value       = one(cloudflare_zero_trust_access_policy.allowlist[*].id)
}

output "protected_urls" {
  description = "URLs now behind Access. Worth eyeballing after an apply."
  value       = [for path in var.protected_paths : "https://${var.domain_name}${path}"]
}
