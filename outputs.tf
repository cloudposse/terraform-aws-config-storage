output "bucket_domain_name" {
  value       = join("", module.storage.*.bucket_domain_name)
  description = "FQDN of bucket"
}

output "bucket_id" {
  value       = join("", module.storage.*.bucket_id)
  description = "Bucket Name (aka ID)"
}

output "bucket_arn" {
  value       = join("", module.storage.*.bucket_arn)
  description = "Bucket ARN"
}

output "prefix" {
  value       = var.lifecycle_prefix
  description = "Prefix configured for lifecycle rules"
}

output "enabled" {
  value       = module.this.enabled
  description = "Is module enabled"
}
