provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

module "project" {
  source  = "terraform-mongodbatlas-modules/project/mongodbatlas"
  version = ">= 0.1, < 1.0"

  org_id = var.org_id
  name   = "my-project"
}

module "cluster" {
  source  = "terraform-mongodbatlas-modules/cluster/mongodbatlas"
  version = ">= 0.1, < 1.0"

  name         = "my-cluster"
  project_id   = module.project.id
  cluster_type = "SHARDED"

  provider_name = "AWS"

  regions = [
    {
      name         = var.region
      node_count   = 3
      shard_number = 0
    }
  ]

  instance_size = "M10"
}
