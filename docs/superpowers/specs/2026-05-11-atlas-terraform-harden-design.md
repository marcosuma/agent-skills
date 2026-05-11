# Design Spec: `atlas-terraform-[aws|azure|gcp]-harden` Skills

**Date:** 2026-05-11  
**Status:** Approved  
**Author:** Marco Suma

---

## Overview

Three new agent skills that guide users through hardening an existing MongoDB Atlas cluster with enterprise-grade security and connectivity features using the official MongoDB Atlas Landing Zone modules. Each skill is cloud-specific and generates a complete, validated, ready-to-`terraform apply` configuration.

This spec covers the **harden-existing** scope: PrivateLink/Private Service Connect, encryption at rest, cloud provider access, and backup export. A follow-up `atlas-terraform-[cloud]-enterprise` skill (deferred) will cover the full from-scratch enterprise path.

---

## Skill Identity

| Field | AWS | Azure | GCP |
|---|---|---|---|
| **Name** | `atlas-terraform-aws-harden` | `atlas-terraform-azure-harden` | `atlas-terraform-gcp-harden` |
| **Location** | `skills/atlas-terraform-aws-harden/SKILL.md` | `skills/atlas-terraform-azure-harden/SKILL.md` | `skills/atlas-terraform-gcp-harden/SKILL.md` |
| **Module** | `terraform-mongodbatlas-modules/atlas-aws/mongodbatlas` | `terraform-mongodbatlas-modules/atlas-azure/mongodbatlas` | `terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas` |
| **Cloud provider** | `hashicorp/aws ~> 5.0` | `hashicorp/azurerm ~> 4.0` | `hashicorp/google ~> 6.0` |
| **Module status** | Public Preview (v0) | Public Preview (v0) | Public Preview (v0) |

**Allowed tools (all three skills):** `mcp__MongoDB__*`, `mcp__plugin_terraform_terraform__get_latest_provider_version`, `WebSearch`, `Bash(gh *)`, `Bash(terraform *)`, `Bash(mkdir *)`, `Bash(rm -rf /tmp/atlas-tf-validate-*)`

### Trigger Description

Triggers when a user wants to add enterprise-grade features (PrivateLink, encryption at rest, backup export) to an **existing** Atlas cluster on the respective cloud:

- "add PrivateLink to my Atlas cluster on AWS"
- "encrypt Atlas at rest with AWS KMS / Azure Key Vault / GCP KMS"
- "Atlas backup export to S3 / Azure Blob / GCS"
- "harden my Atlas cluster on AWS / Azure / GCP"
- "add private endpoints to my Atlas cluster"
- "atlas-terraform AWS / Azure / GCP enterprise features"

**Does NOT trigger for:**
- Creating a new cluster → `atlas-terraform-getting-started`
- The other two cloud providers → redirect to the correct harden skill
- Network peering, VPC peering, audit log configuration, data federation
- Full enterprise from-scratch (cluster + hardening) → deferred `atlas-terraform-[cloud]-enterprise` skill

---

## Features Generated

Each skill always generates configuration for **all** features bundled in the respective module:

| Feature | AWS | Azure | GCP |
|---|---|---|---|
| Cloud networking (optional) | VPC + subnets | Resource Group + VNet + subnet | VPC network + subnetwork |
| Private connectivity | PrivateLink (VPC endpoint) | Azure Private Endpoint | Private Service Connect |
| Encryption at rest | AWS KMS | Azure Key Vault | GCP Cloud KMS |
| Cloud provider access | IAM role | Service principal | Service account |
| Backup export | S3 bucket | Azure Blob (storage account + container) | GCS bucket |
| Log export (optional) | S3 (same or separate bucket) | Azure Blob | GCS |

For cloud networking: the skill asks whether the user has an existing VPC/subnet. If not, it generates Terraform resources to create one using the native cloud provider (`hashicorp/aws`, `hashicorp/azurerm`, `hashicorp/google`). This is controlled by `create_vpc` / `create_vnet` / `create_network` boolean variables.

For encryption, backup, and log export, the skill supports two modes:
- **Module-managed:** module creates the cloud resource (KMS key, bucket, etc.)
- **Bring-your-own (BYO):** user provides an existing resource identifier

---

## Interactive Flow

### Step 0 — Disclosure (always first)

> "I'll add PrivateLink, encryption at rest, and backup export to your existing Atlas cluster using the official [MongoDB Atlas Landing Zone Module for [AWS/Azure/GCP]](https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-[aws|azure|gcp]/mongodbatlas/latest). This module is officially maintained by MongoDB."

### Step 1 — Resolve Latest Versions

Try each source in order until one succeeds:

**mongodbatlas provider:**
1. `mcp__plugin_terraform_terraform__get_latest_provider_version`: namespace `mongodb`, type `mongodbatlas`
2. `WebSearch`: `mongodb/mongodbatlas terraform provider latest release site:github.com`
3. `Bash`: `gh api repos/mongodb/terraform-provider-mongodbatlas/releases/latest --jq '.tag_name'`

Constraint: `~> 2.0`

**Cloud provider:**
1. `mcp__plugin_terraform_terraform__get_latest_provider_version`: namespace `hashicorp`, type `aws` / `azurerm` / `google`
2. `WebSearch`: `hashicorp/[aws|azurerm|google] terraform provider latest release`
3. `Bash`: `gh api repos/hashicorp/terraform-provider-[aws|azurerm|google]/releases/latest --jq '.tag_name'`

Constraints: `~> 5.0` (AWS), `~> 4.0` (Azure), `~> 6.0` (GCP)

**Module version:**
1. `WebSearch`: `terraform-mongodbatlas-modules/atlas-[aws|azure|gcp] terraform registry latest version`
2. `Bash`: `gh api repos/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-[aws|azure|gcp]/releases/latest --jq '.tag_name'`

Constraint: `>= 0.1, < 1.0` (all three modules are Public Preview v0)

### Step 2 — Gather User Inputs (5 questions in sequence)

**Q1 — Project ID**
> "What is your Atlas Project ID?"

- If MCP connected: call `mcp__MongoDB__atlas-list-projects` and present the list to pick from.

**Q2 — PrivateLink region and networking**
> "Which region do you want to enable private connectivity in?"

- If MCP connected: call `mcp__MongoDB__atlas-list-clusters` to surface regions where the existing cluster runs as suggestions.

**Q2a — Existing network or create one?**
> "Do you have an existing [VPC (AWS) / Virtual Network (Azure) / VPC network (GCP)] in that region, or should I generate Terraform to create one?"

**If BYO (existing network):**
- AWS: "What are your subnet IDs?" (list; must be in the same region)
- Azure: "What is your subnet resource ID?" (full ARM resource ID)
- GCP: "What is your subnetwork self-link?" (full `projects/.../subnetworks/...` URL)

**If creating a new network** (user has no existing VPC/VNet):

AWS — collect:
- VPC CIDR (default `10.0.0.0/16`)
- Availability zones to create subnets in (default: first 2 AZs in the chosen region, e.g. `us-east-1a`, `us-east-1b`)

Azure — collect:
- Resource group name (to create or reuse)
- Azure location (e.g. `eastus2`) — must match the Atlas region
- VNet address space (default `10.0.0.0/16`)
- Subnet prefix (default `10.0.1.0/24`)

GCP — collect:
- GCP project ID (the GCP project, not the Atlas project)
- GCP region (e.g. `us-central1`) — must match the Atlas region
- Subnet CIDR (default `10.0.0.0/24`)

**Q3 — Encryption at rest**
> "For encryption at rest, should I create a new [AWS KMS key / Azure Key Vault key / GCP Cloud KMS key], or do you have an existing one?"

- Module-managed: no additional input needed.
- BYO: collect [AWS: KMS key ARN / Azure: Key Vault ID + key identifier / GCP: key version resource ID].

**Q4 — Backup export**
> "For backup export, should I create a new [S3 bucket / Azure storage account + container / GCS bucket], or do you have an existing one?"

- Module-managed: no additional input needed.
- BYO: collect [AWS: S3 bucket name / Azure: storage account resource ID + container name / GCP: GCS bucket name].

**Q5 — Log export (optional)**
> "Do you also want to export cluster logs to [S3/Azure Blob/GCS]? Press Enter to skip."

- If yes: defaults to the same bucket/container as backup export. Ask if they want a separate one.

---

## Validation Before Presenting

After generating all 5 files, the skill validates the configuration before presenting it to the user:

1. Write files to a temp directory: `mkdir -p /tmp/atlas-tf-validate-<random>/`
2. Run `terraform init -backend=false` (downloads providers and modules; no credentials needed)
3. Run `terraform validate`
4. If errors: fix them in memory, rewrite, re-validate (loop until clean)
5. Present the validated files with the note: *"✓ Validated with `terraform validate`"*
6. Clean up: `rm -rf /tmp/atlas-tf-validate-<random>/`

`terraform validate` checks syntax, required arguments, type correctness, and valid references — it does not make API calls and does not require Atlas or cloud credentials.

---

## Generated Output (5 Files)

All module versions pinned to the latest available at generation time. BYO vs module-managed is expressed via `null`-defaulted variables.

### `versions.tf`

```hcl
terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.0"  # latest resolved: ATLAS_PROVIDER_VERSION
    }
    # AWS:
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # latest resolved: CLOUD_PROVIDER_VERSION
    }
    # Azure:
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # GCP:
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.9"
}
```

Include only the relevant cloud provider block.

### `variables.tf`

**Common (all three skills):**
```hcl
variable "atlas_client_id" {
  description = "MongoDB Atlas Service Account client ID."
  type        = string
  sensitive   = true
}

variable "atlas_client_secret" {
  description = "MongoDB Atlas Service Account client secret."
  type        = string
  sensitive   = true
}

# Alternative: API Key credentials
# variable "atlas_public_key"  { type = string; sensitive = true }
# variable "atlas_private_key" { type = string; sensitive = true }

variable "project_id" {
  description = "MongoDB Atlas Project ID. Atlas UI → Project Settings → Project ID."
  type        = string
}
```

**AWS-specific:**
```hcl
variable "atlas_region" {
  description = "Atlas region name, e.g. US_EAST_1. Must match the AWS region where the VPC lives."
  type        = string
}

# Networking — BYO path
variable "subnet_ids" {
  description = "Existing AWS subnet IDs for PrivateLink. Leave null when create_vpc = true."
  type        = list(string)
  default     = null
}

# Networking — create path (ignored when subnet_ids is set)
variable "create_vpc" {
  description = "Set to true to create a new VPC and subnets. Set to false when providing subnet_ids."
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC. Only used when create_vpc = true."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to create subnets in. Only used when create_vpc = true."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Encryption at rest
variable "kms_key_arn" {
  description = "Existing AWS KMS key ARN. Leave null to let the module create one."
  type        = string
  default     = null
}

# Backup export
variable "s3_bucket_name" {
  description = "Existing S3 bucket name for backup export. Leave null to let the module create one."
  type        = string
  default     = null
}
```

**Azure-specific:**
```hcl
variable "atlas_region" {
  description = "Atlas region name, e.g. US_EAST_2."
  type        = string
}

variable "azure_location" {
  description = "Azure location, e.g. eastus2. Must correspond to the Atlas region."
  type        = string
}

# Networking — BYO path
variable "subnet_id" {
  description = "Existing Azure subnet resource ID for Private Endpoint. Leave null when create_vnet = true."
  type        = string
  default     = null
}

# Networking — create path
variable "create_vnet" {
  description = "Set to true to create a new Resource Group, VNet, and subnet."
  type        = bool
  default     = false
}

variable "resource_group_name" {
  description = "Name for the new resource group. Only used when create_vnet = true."
  type        = string
  default     = "atlas-harden-rg"
}

variable "vnet_address_space" {
  description = "Address space for the new VNet. Only used when create_vnet = true."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the new subnet. Only used when create_vnet = true."
  type        = string
  default     = "10.0.1.0/24"
}

# Encryption at rest
variable "key_vault_id" {
  description = "Existing Azure Key Vault resource ID. Leave null to let the module create one."
  type        = string
  default     = null
}

variable "key_identifier" {
  description = "Existing Azure Key Vault key identifier URL. Leave null to let the module create one."
  type        = string
  default     = null
}

# Backup export
variable "storage_account_id" {
  description = "Existing Azure storage account resource ID for backup. Leave null to let the module create one."
  type        = string
  default     = null
}

variable "backup_container_name" {
  description = "Existing Azure Blob container name for backup. Leave null to let the module create one."
  type        = string
  default     = null
}
```

**GCP-specific:**
```hcl
variable "atlas_region" {
  description = "Atlas region name, e.g. CENTRAL_US."
  type        = string
}

variable "gcp_region" {
  description = "GCP region, e.g. us-central1. Must correspond to the Atlas region."
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID where network resources will be created."
  type        = string
}

# Networking — BYO path
variable "subnetwork" {
  description = "Existing subnetwork self-link for Private Service Connect. Leave null when create_network = true."
  type        = string
  default     = null
}

# Networking — create path
variable "create_network" {
  description = "Set to true to create a new VPC network and subnetwork."
  type        = bool
  default     = false
}

variable "subnet_cidr" {
  description = "CIDR range for the new subnetwork. Only used when create_network = true."
  type        = string
  default     = "10.0.0.0/24"
}

# Encryption at rest
variable "kms_key_version_resource_id" {
  description = "Existing GCP KMS key version resource ID. Leave null to let the module create one."
  type        = string
  default     = null
}

# Backup export
variable "gcs_bucket_name" {
  description = "Existing GCS bucket name for backup export. Leave null to let the module create one."
  type        = string
  default     = null
}
```

### `main.tf`

**AWS:**
```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "aws" {}  # region set via AWS_DEFAULT_REGION env var or aws configure

# ── Networking (only when create_vpc = true) ──────────────────────────────────
resource "aws_vpc" "atlas" {
  count                = var.create_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "atlas" {
  count             = var.create_vpc ? length(var.availability_zones) : 0
  vpc_id            = aws_vpc.atlas[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]
}

locals {
  subnet_ids = var.create_vpc ? aws_subnet.atlas[*].id : var.subnet_ids
}
# ─────────────────────────────────────────────────────────────────────────────

module "atlas_aws" {
  source  = "terraform-mongodbatlas-modules/atlas-aws/mongodbatlas"
  version = ">= 0.1, < 1.0"

  project_id = var.project_id

  cloud_provider_access = { create = true }

  encryption = {
    enabled     = true
    kms_key_arn = var.kms_key_arn
    create_kms_key = {
      enabled = var.kms_key_arn == null
    }
  }

  backup_export = {
    enabled     = true
    bucket_name = var.s3_bucket_name
    create_s3_bucket = {
      enabled = var.s3_bucket_name == null
    }
  }

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnet_ids = local.subnet_ids
    }
  ]
}
```

If log export was requested (Q5 = yes), append this block inside `module "atlas_aws"`:
```hcl
  # Only add this block when the user answered yes to Q5 (log export)
  log_integration = {
    enabled     = true
    bucket_name = var.s3_bucket_name  # same bucket as backup, or separate if user specified
    integrations = [{ log_types = ["MONGODB", "MONGOS"] }]
  }
```

**Azure:**
```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "azurerm" {
  features {}
}

# ── Networking (only when create_vnet = true) ─────────────────────────────────
resource "azurerm_resource_group" "atlas" {
  count    = var.create_vnet ? 1 : 0
  name     = var.resource_group_name
  location = var.azure_location
}

resource "azurerm_virtual_network" "atlas" {
  count               = var.create_vnet ? 1 : 0
  name                = "atlas-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.atlas[0].location
  resource_group_name = azurerm_resource_group.atlas[0].name
}

resource "azurerm_subnet" "atlas" {
  count                = var.create_vnet ? 1 : 0
  name                 = "atlas-subnet"
  resource_group_name  = azurerm_resource_group.atlas[0].name
  virtual_network_name = azurerm_virtual_network.atlas[0].name
  address_prefixes     = [var.subnet_address_prefix]
}

locals {
  subnet_id = var.create_vnet ? azurerm_subnet.atlas[0].id : var.subnet_id
}
# ─────────────────────────────────────────────────────────────────────────────

module "atlas_azure" {
  source  = "terraform-mongodbatlas-modules/atlas-azure/mongodbatlas"
  version = ">= 0.1, < 1.0"

  project_id = var.project_id

  create_service_principal = true

  encryption = {
    enabled        = true
    key_vault_id   = var.key_vault_id
    key_identifier = var.key_identifier
    create_key_vault = {
      enabled = var.key_vault_id == null
    }
  }

  backup_export = {
    enabled                = true
    storage_account_id     = var.storage_account_id
    container_name         = var.backup_container_name
    create_storage_account = {
      enabled = var.storage_account_id == null
    }
  }

  privatelink_endpoints = [
    {
      region    = var.atlas_region
      subnet_id = local.subnet_id
    }
  ]
}
```

**GCP:**
```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ── Networking (only when create_network = true) ──────────────────────────────
resource "google_compute_network" "atlas" {
  count                   = var.create_network ? 1 : 0
  name                    = "atlas-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "atlas" {
  count         = var.create_network ? 1 : 0
  name          = "atlas-subnet"
  network       = google_compute_network.atlas[0].id
  ip_cidr_range = var.subnet_cidr
  region        = var.gcp_region
}

locals {
  subnetwork = var.create_network ? google_compute_subnetwork.atlas[0].self_link : var.subnetwork
}
# ─────────────────────────────────────────────────────────────────────────────

module "atlas_gcp" {
  source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version = ">= 0.1, < 1.0"

  project_id = var.project_id

  cloud_provider_access = { create = true }

  encryption = {
    enabled                 = true
    key_version_resource_id = var.kms_key_version_resource_id
    create_kms_key = {
      enabled = var.kms_key_version_resource_id == null
    }
  }

  backup_export = {
    enabled     = true
    bucket_name = var.gcs_bucket_name
    create_bucket = {
      enabled = var.gcs_bucket_name == null
    }
  }

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnetwork = local.subnetwork
    }
  ]
}
```

### `outputs.tf`

> **Implementer note:** Verify the exact output names by running `terraform-mongodbatlas-modules/atlas-[aws|azure|gcp]` module locally or reading the module's `outputs.tf` before writing these. The names below are best-effort and may differ slightly.

**AWS:**
```hcl
output "privatelink_endpoints" {
  description = "PrivateLink endpoint details."
  value       = module.atlas_aws.privatelink_endpoints
}

output "encryption_at_rest_provider" {
  description = "Encryption at rest provider confirmed by Atlas."
  value       = module.atlas_aws.encryption_at_rest_provider
}

output "cloud_provider_access_role_id" {
  description = "Atlas Cloud Provider Access IAM role ID."
  value       = module.atlas_aws.role_id
}

# Networking outputs — only populated when create_vpc = true
output "vpc_id" {
  description = "ID of the created VPC (null if BYO)."
  value       = var.create_vpc ? aws_vpc.atlas[0].id : null
}

output "subnet_ids" {
  description = "IDs of the created subnets (null if BYO)."
  value       = var.create_vpc ? aws_subnet.atlas[*].id : null
}
```

**Azure:**
```hcl
output "privatelink_endpoints" {
  description = "Azure Private Endpoint details."
  value       = module.atlas_azure.privatelink_endpoints
}

output "encryption_at_rest_provider" {
  value = module.atlas_azure.encryption_at_rest_provider
}

output "service_principal_id" {
  description = "Azure AD service principal ID."
  value       = module.atlas_azure.service_principal_id
}

# Networking outputs — only populated when create_vnet = true
output "vnet_id" {
  description = "ID of the created VNet (null if BYO)."
  value       = var.create_vnet ? azurerm_virtual_network.atlas[0].id : null
}

output "subnet_id" {
  description = "ID of the created subnet (null if BYO)."
  value       = var.create_vnet ? azurerm_subnet.atlas[0].id : null
}
```

**GCP:**
```hcl
output "privatelink_endpoints" {
  description = "Private Service Connect endpoint details."
  value       = module.atlas_gcp.privatelink_endpoints
}

output "encryption_at_rest_provider" {
  value = module.atlas_gcp.encryption_at_rest_provider
}

output "service_account_email" {
  description = "GCP service account email for Cloud Provider Access."
  value       = module.atlas_gcp.service_account_email
}

# Networking outputs — only populated when create_network = true
output "network_self_link" {
  description = "Self-link of the created VPC network (null if BYO)."
  value       = var.create_network ? google_compute_network.atlas[0].self_link : null
}

output "subnetwork_self_link" {
  description = "Self-link of the created subnetwork (null if BYO)."
  value       = var.create_network ? google_compute_subnetwork.atlas[0].self_link : null
}
```

### `terraform.tfvars.example`

The skill generates the example file in the correct path for the user's chosen path (BYO network or create network). Both variants are shown here.

**AWS — BYO subnet:**
```hcl
# Copy to terraform.tfvars — NEVER commit this file.

atlas_client_id     = "<replace-me>"  # Atlas UI → Access Manager → Service Accounts
atlas_client_secret = "<replace-me>"

project_id   = "<replace-me>"   # Atlas UI → Project Settings → Project ID
atlas_region = "US_EAST_1"

# Networking — BYO existing subnet
create_vpc = false
subnet_ids = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]

# Encryption at rest (leave commented out to let the module create a key)
# kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/xxxxxxxx"

# Backup export (leave commented out to let the module create a bucket)
# s3_bucket_name = "my-atlas-backup-bucket"
```

**AWS — create new VPC:**
```hcl
atlas_client_id     = "<replace-me>"
atlas_client_secret = "<replace-me>"

project_id   = "<replace-me>"
atlas_region = "US_EAST_1"

# Networking — create new VPC
create_vpc         = true
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
```

**Azure — BYO subnet:**
```hcl
atlas_client_id     = "<replace-me>"
atlas_client_secret = "<replace-me>"

project_id     = "<replace-me>"
atlas_region   = "US_EAST_2"
azure_location = "eastus2"

# Networking — BYO existing subnet
create_vnet = false
subnet_id   = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>"

# key_vault_id    = "..."
# key_identifier  = "..."
# storage_account_id    = "..."
# backup_container_name = "atlas-backup"
```

**Azure — create new VNet:**
```hcl
atlas_client_id     = "<replace-me>"
atlas_client_secret = "<replace-me>"

project_id     = "<replace-me>"
atlas_region   = "US_EAST_2"
azure_location = "eastus2"

# Networking — create new VNet
create_vnet           = true
resource_group_name   = "atlas-harden-rg"
vnet_address_space    = "10.0.0.0/16"
subnet_address_prefix = "10.0.1.0/24"
```

**GCP — BYO subnetwork:**
```hcl
atlas_client_id     = "<replace-me>"
atlas_client_secret = "<replace-me>"

project_id     = "<replace-me>"
atlas_region   = "CENTRAL_US"
gcp_region     = "us-central1"
gcp_project_id = "<gcp-project-id>"

# Networking — BYO existing subnetwork
create_network = false
subnetwork     = "projects/<gcp-project>/regions/us-central1/subnetworks/<subnet>"

# kms_key_version_resource_id = "..."
# gcs_bucket_name = "my-atlas-backup-bucket"
```

**GCP — create new network:**
```hcl
atlas_client_id     = "<replace-me>"
atlas_client_secret = "<replace-me>"

project_id     = "<replace-me>"
atlas_region   = "CENTRAL_US"
gcp_region     = "us-central1"
gcp_project_id = "<gcp-project-id>"

# Networking — create new VPC network
create_network = true
subnet_cidr    = "10.0.0.0/24"
```

If MCP is connected, `project_id` is pre-filled with the real value.

---

## Post-Generation Block

```
## Next Steps

1. Copy `terraform.tfvars.example` → `terraform.tfvars` and fill in your values.
   Add to `.gitignore`:
     terraform.tfvars
     .terraform/
     *.tfstate
     *.tfstate.backup

2. Review Cloud Provider Access — Atlas needs an IAM role / service principal /
   service account to manage encryption and backup on your behalf:
   [AWS]   The module creates an IAM role. After apply, check
           Outputs > cloud_provider_access_role for the role ARN.
   [Azure] The module creates a service principal. Ensure your Terraform runner
           has permission to create Azure AD applications.
   [GCP]   The module creates a service account. Ensure your runner has
           roles/iam.serviceAccountAdmin in the target GCP project.

3. terraform init
4. terraform plan
5. terraform apply

## Further Customization

| What you want | How |
|---|---|
| Use existing VPC/subnet instead of creating one | Set `create_vpc = false` and provide `subnet_ids` |
| Multiple PrivateLink regions | Add more endpoint objects to `privatelink_endpoints` in `main.tf` |
| Bring-your-own encryption key | Set `kms_key_arn` / `key_identifier` / `key_version_resource_id` |
| Bring-your-own backup bucket | Set `s3_bucket_name` / `container_name` / `gcs_bucket_name` |
| Log export to same bucket | Add `log_integration = { enabled = true, ... }` inside the module block |
| Bring-your-own IAM role | Set `cloud_provider_access = { create = false, existing = { ... } }` |
| Search node encryption | Set `enabled_for_search_nodes = true` in the `encryption` block |

Full variable reference:
  AWS:   https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-aws/mongodbatlas/latest?tab=inputs
  Azure: https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-azure/mongodbatlas/latest?tab=inputs
  GCP:   https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas/latest?tab=inputs

## Useful Links

- Atlas Landing Zone Modules: https://registry.terraform.io/namespaces/terraform-mongodbatlas-modules
- Atlas Provider docs:        https://registry.terraform.io/providers/mongodb/mongodbatlas/latest/docs
- Atlas regions:              https://www.mongodb.com/docs/atlas/cloud-providers-regions/
- Service Account setup:      https://www.mongodb.com/docs/atlas/configure-api-access/
```

---

## Out of Scope (This Skill)

| Request | Redirect |
|---|---|
| Creating a new cluster | `atlas-terraform-getting-started` skill |
| Other cloud provider | Redirect to the correct harden skill |
| Network peering / VPC peering | Raw `mongodbatlas_network_peering` resource docs |
| Audit log configuration | `mongodbatlas_audit` resource docs |
| Data Federation | Atlas Data Federation Terraform docs |
| Full enterprise from-scratch (cluster + hardening) | Deferred — `atlas-terraform-[cloud]-enterprise` skill |

---

## Retrofit: `atlas-terraform-getting-started` Validation

The same `terraform validate` step (write to temp dir → init → validate → fix if needed → present) is added to `atlas-terraform-getting-started` as well, to prevent the class of bugs (missing required arguments, wrong output access patterns) found during initial testing.

Both the new harden skills and the retrofitted getting-started skill require `Bash(terraform *)` and `Bash(mkdir *)` in their `allowed-tools`.
