output "connection_string" {
  description = "MongoDB SRV connection string."
  value       = tolist(module.cluster.connection_strings)[0].standard_srv
}

output "project_id" {
  description = "Atlas project ID."
  value       = module.project.id
}

output "cluster_id" {
  description = "Atlas cluster ID."
  value       = module.cluster.cluster_id
}
