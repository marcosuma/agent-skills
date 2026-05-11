---
name: atlas-terraform-azure-harden
description: >-
  Use this skill when a user has an existing MongoDB Atlas cluster and wants to harden it
  with Azure security features using Terraform: Azure Private Link private endpoints, Azure
  Key Vault customer-managed encryption at rest (CMEK), Azure service principal for Cloud
  Provider Access, and backup export to Azure Blob Storage. Triggers on: "add Private Link
  to my Atlas cluster on Azure", "enable Azure Key Vault encryption Atlas", "harden Atlas
  cluster Azure Terraform", "Atlas Azure private endpoint Terraform", "backup export Azure
  Blob Atlas", "Atlas Azure Key Vault CMEK", "secure my Atlas cluster Azure". Also triggers
  when user already ran atlas-terraform-getting-started and now wants Azure security hardening.
  Does NOT trigger for: initial Atlas cluster creation (atlas-terraform-getting-started),
  AWS or GCP cloud integrations, Atlas Search, Vector Search, or general MongoDB querying.
allowed-tools: mcp__MongoDB__*, mcp__plugin_terraform_terraform__get_latest_provider_version, WebSearch, Bash(gh *), Bash(terraform *), Bash(mkdir *), Bash(rm -rf /tmp/atlas-tf-validate-*)
---

# MongoDB Atlas Terraform — Azure Hardening

You generate complete, ready-to-`terraform apply` Terraform configurations that add Azure security
hardening to an existing Atlas cluster using the official
`terraform-mongodbatlas-modules/atlas-azure/mongodbatlas` Landing Zone module.
Follow this workflow in order.

---

## Step 0: Module Disclosure (Always First)

Before asking any questions, show:

> I'll generate your Azure hardening configuration using the official [MongoDB Atlas Azure Landing Zone
> Module](https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-azure/mongodbatlas/latest),
> maintained by MongoDB. This adds Azure Private Link, Key Vault encryption at rest, Azure service
> principal Cloud Provider Access, and Blob Storage backup export to your existing Atlas cluster.
>
> **Note:** This module is in Public Preview (v0). It is officially supported by MongoDB but
> upgrades from v0 → v1 may require manual migration steps.

---

## Step 1: Resolve Latest Versions

Fetch versions before generating HCL. Never hardcode them.

### 1a: mongodbatlas provider

Try in order until one succeeds:
1. `mcp__plugin_terraform_terraform__get_latest_provider_version`: namespace `mongodb`, type `mongodbatlas`
2. `WebSearch`: query `mongodb/mongodbatlas terraform provider latest release site:github.com`
3. `Bash`: `gh api repos/mongodb/terraform-provider-mongodbatlas/releases/latest --jq '.tag_name'`

Strip the leading `v`. Constraint: `~> 2.0`.

### 1b: atlas-azure module

Try in order:
1. `WebSearch`: query `terraform-mongodbatlas-modules/atlas-azure/mongodbatlas terraform registry latest version`
2. `Bash`: `gh api repos/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-azure/releases/latest --jq '.tag_name'`

Constraint: `~> 0.3`. Public Preview module.

### 1c: Azure providers

- `hashicorp/azurerm` requires `>= 4.42`. Constraint: `~> 4.0`.
- `hashicorp/azuread` requires `>= 2.53`. Constraint: `~> 2.0`.

No version resolution needed for these.

---

## Step 2: Gather User Inputs

Ask questions in sequence. Stop after each answer.

### Q1 — Atlas Project ID

Ask: "What is your Atlas Project ID?"
If MCP is connected: call `mcp__MongoDB__atlas-list-projects` and present the list.
Store as `USER_PROJECT_ID`.

### Q2 — Cluster Name

Ask: "What is the name of your existing Atlas cluster?"
If MCP is connected: call `mcp__MongoDB__atlas-list-clusters` with the project ID and present the list.
Store as `USER_CLUSTER_NAME`.

### Q3 — Region and Location

Ask for both: Atlas region format (e.g. US_EAST_2) and Azure location format (e.g. eastus2).
Store as `USER_ATLAS_REGION` and `USER_AZURE_LOCATION`.

### Q4 — Azure Subscription and Resource Group

Ask for Azure Subscription ID → store as `USER_SUBSCRIPTION_ID`.
Ask for Azure Resource Group name (must already exist) → store as `USER_RESOURCE_GROUP`.

### Q5 — Azure Networking

Ask: "Do you have an existing Azure subnet for Private Link, or should I create a new VNet and subnet?"

**BYO:** Ask for the full subnet resource ID → store as `USER_SUBNET_ID`. Set `NETWORKING = byo`.

**Create:** Ask for VNet address space (e.g. 10.0.0.0/16) and subnet prefix (e.g. 10.0.1.0/24).
Store as `USER_VNET_ADDRESS_SPACE` and `USER_SUBNET_PREFIX`. Set `NETWORKING = create`.

### Q6 — Key Vault Encryption

Ask: "Do you have an existing Azure Key Vault for Atlas CMEK, or should I create a new one?"

**BYO:** Ask for Key Vault resource ID and key identifier URI (`https://<vault>.vault.azure.net/keys/<key>/<version>`).
Store as `USER_KEY_VAULT_ID` and `USER_KEY_IDENTIFIER`. Set `KMS = byo`.

**Create:** Ask for Key Vault name (3–24 chars, globally unique) → store as `USER_KEY_VAULT_NAME`. Set `KMS = create`.

### Q7 — Blob Storage Backup Export

Ask: "Do you have an existing Azure Storage Account for Atlas backup export, or should I create a new one?"

**BYO:** Ask for Storage Account resource ID and container name → store as `USER_STORAGE_ACCOUNT_ID` and `USER_CONTAINER_NAME`. Set `BLOB = byo`.

**Create:** Ask for Storage Account name (3–24 chars, lowercase alphanumeric) and container name → store as `USER_STORAGE_ACCOUNT_NAME` and `USER_CONTAINER_NAME`. Set `BLOB = create`.

---

## Step 3: Generate the 5 Files

Substitute all USER_* placeholders with collected answers before rendering.

For `terraform.tfvars.example`, activate only the networking block matching the user's Q5 choice
and delete the other networking block entirely. Do the same for Key Vault (Q6) and Storage Account
(Q7) blocks — keep only the block matching the user's choice, delete the other.

---

### File 1: `versions.tf`

```hcl
terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.0"  # resolved: MONGODBATLAS_VERSION
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.9"
}
```

Replace `MONGODBATLAS_VERSION` with the version from Step 1a.

---

### File 2: `variables.tf`

Always include:

```hcl
variable "atlas_client_id" {
  description = "Atlas Service Account client ID. Atlas UI → Access Manager → Service Accounts."
  type        = string
  sensitive   = true
}

variable "atlas_client_secret" {
  description = "Atlas Service Account client secret."
  type        = string
  sensitive   = true
}

variable "project_id" {
  description = "Atlas Project ID."
  type        = string
}

variable "cluster_name" {
  description = "Name of the existing Atlas cluster to harden."
  type        = string
}

variable "atlas_region" {
  description = "Atlas region (e.g. US_EAST_2)."
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID."
  type        = string
}

variable "azure_location" {
  description = "Azure location (e.g. eastus2)."
  type        = string
}

variable "resource_group_name" {
  description = "Existing Azure Resource Group name."
  type        = string
}
```

Append networking variables (Q5):

**`NETWORKING = byo`:** `variable "subnet_id"` (description: full subnet resource ID, type = string)

**`NETWORKING = create`:** `variable "vnet_address_space"` and `variable "subnet_prefix"` (both type = string)

Append Key Vault variables (Q6):

**`KMS = byo`:** `variable "key_vault_id"` and `variable "key_identifier"` (both type = string)

**`KMS = create`:** `variable "key_vault_name"` (type = string)

Append Storage Account variables (Q7):

**`BLOB = byo`:** `variable "storage_account_id"` (type = string)

**`BLOB = create`:** `variable "storage_account_name"` (type = string)

Always append:
```hcl
variable "backup_container_name" {
  description = "Azure Blob container name for Atlas backup export."
  type        = string
}
```

---

### File 3: `main.tf`

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "azuread" {}

# --- NETWORKING = create only: include azurerm_virtual_network + azurerm_subnet resources ---
resource "azurerm_virtual_network" "atlas" {
  name                = "atlas-harden-vnet"
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]
}

resource "azurerm_subnet" "atlas" {
  name                 = "atlas-harden-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.atlas.name
  address_prefixes     = [var.subnet_prefix]
}
# --- end NETWORKING = create block ---

module "atlas_azure" {
  source  = "terraform-mongodbatlas-modules/atlas-azure/mongodbatlas"
  version = "~> 0.3"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  # Creates an Azure service principal for Atlas Cloud Provider Access (Key Vault + Storage permissions).
  create_service_principal = true

  privatelink_endpoints = [
    {
      region    = var.atlas_region
      subnet_id = SUBNET_ID_PLACEHOLDER
    }
  ]

  encryption    = KMS_PLACEHOLDER
  backup_export = BLOB_PLACEHOLDER
}
```

> **Note on `atlas_azure_app_id`:** The default value `9f2deb0d-be22-4524-a403-df531868bac0` is MongoDB's registered Azure AD application ID — do not set it manually unless your organization uses a custom registration.

⚠️ **Combination rules:** Replace each placeholder based on user answers.

| Choice | Placeholder | Substitute with |
|---|---|---|
| NETWORKING = byo | `SUBNET_ID_PLACEHOLDER` | `var.subnet_id` |
| NETWORKING = create | `SUBNET_ID_PLACEHOLDER` | `azurerm_subnet.atlas.id` |
| NETWORKING = create | azurerm_virtual_network + azurerm_subnet resources | **keep** |
| NETWORKING = byo | azurerm_virtual_network + azurerm_subnet resources | **remove** |
| KMS = byo | `KMS_PLACEHOLDER` | `{ enabled = true, key_vault_id = var.key_vault_id, key_identifier = var.key_identifier }` |
| KMS = create | `KMS_PLACEHOLDER` | `{ enabled = true, create_key_vault = { enabled = true, name = var.key_vault_name, resource_group_name = var.resource_group_name, azure_location = var.azure_location } }` |
| BLOB = byo | `BLOB_PLACEHOLDER` | `{ enabled = true, container_name = var.backup_container_name, storage_account_id = var.storage_account_id }` |
| BLOB = create | `BLOB_PLACEHOLDER` | `{ enabled = true, container_name = var.backup_container_name, create_storage_account = { enabled = true, name = var.storage_account_name, resource_group_name = var.resource_group_name, azure_location = var.azure_location } }` |

---

### File 4: `outputs.tf`

```hcl
output "privatelink_endpoint" {
  description = "Atlas Private Link endpoint details."
  value       = module.atlas_azure.privatelink
}

output "encryption_at_rest_provider" {
  description = "Atlas encryption at rest provider configuration."
  value       = module.atlas_azure.encryption_at_rest_provider
}

output "cloud_provider_access_role_id" {
  description = "Atlas Cloud Provider Access service principal role ID."
  value       = module.atlas_azure.role_id
}

output "backup_export_bucket_id" {
  description = "Atlas backup export container ID."
  value       = module.atlas_azure.export_bucket_id
}
```

If `NETWORKING = create`, append:

```hcl
output "vnet_id" {
  description = "ID of the created Virtual Network."
  value       = azurerm_virtual_network.atlas.id
}

output "subnet_id" {
  description = "ID of the created subnet."
  value       = azurerm_subnet.atlas.id
}
```

---

### File 5: `terraform.tfvars.example`

```hcl
# Copy to terraform.tfvars and fill in values.
# ⚠️  NEVER commit terraform.tfvars to version control.

# Atlas Service Account
# Atlas UI → Access Manager → Service Accounts → Create Service Account
atlas_client_id     = "<replace-me>"
atlas_client_secret = "<replace-me>"

# Atlas project and cluster
project_id   = "USER_PROJECT_ID"
cluster_name = "USER_CLUSTER_NAME"

# Region
atlas_region   = "USER_ATLAS_REGION"    # e.g. US_EAST_2
azure_location = "USER_AZURE_LOCATION"  # e.g. eastus2

# Azure
azure_subscription_id = "USER_SUBSCRIPTION_ID"
resource_group_name   = "USER_RESOURCE_GROUP"

# --- Networking: keep only the block matching your Q5 answer ---

# BYO path: existing subnet resource ID
subnet_id = "/subscriptions/SUB/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET/subnets/SUBNET"

# Create path: remove subnet_id above and uncomment these
# vnet_address_space = "10.0.0.0/16"
# subnet_prefix      = "10.0.1.0/24"

# --- Key Vault: keep only one block, delete the other ---

# BYO path: existing Key Vault
key_vault_id   = "/subscriptions/SUB/resourceGroups/RG/providers/Microsoft.KeyVault/vaults/VAULT"
key_identifier = "https://<vault>.vault.azure.net/keys/<key>/<version>"

# Create path: delete key_vault_id / key_identifier above and keep this
# key_vault_name = "USER_KEY_VAULT_NAME"

# --- Storage Account: keep only one block, delete the other ---

# BYO path: existing storage account
storage_account_id = "/subscriptions/SUB/resourceGroups/RG/providers/Microsoft.Storage/storageAccounts/ACCT"

# Create path: delete storage_account_id above and keep this
# storage_account_name = "USER_STORAGE_ACCOUNT_NAME"

# Always required
backup_container_name = "USER_CONTAINER_NAME"
```

Replace USER_* placeholders with actual values from Q1–Q7. Pre-populate known values if MCP is connected.

---

## Step 4: Validate the Generated Configuration

Before presenting files, validate the HCL:

**4.1** Create a temporary directory:

```bash
mkdir -p /tmp/atlas-tf-validate-tmp
```

**4.2** Write `versions.tf`, `variables.tf`, `main.tf`, and `outputs.tf` into `/tmp/atlas-tf-validate-tmp/`. Do not write `terraform.tfvars.example` — it is not valid HCL for validation.

**4.3** Initialise Terraform:

```bash
terraform -chdir=/tmp/atlas-tf-validate-tmp init -backend=false -no-color
```

**4.4** Validate the configuration:

```bash
terraform -chdir=/tmp/atlas-tf-validate-tmp validate -no-color
```

If output contains `Success! The configuration is valid.` → proceed to Step 5.
If validation fails → fix the error and re-validate. After two failed attempts, present files with a note that HCL validation could not be completed.

**Always clean up:**

```bash
rm -rf /tmp/atlas-tf-validate-tmp
```

---

## Step 5: Post-Generation Block

After presenting all 5 files, always append:

```
## Next Steps
1. Copy terraform.tfvars.example → terraform.tfvars. Add to .gitignore:
     terraform.tfvars
     .terraform/
     *.tfstate
     *.tfstate.backup
2. az login
3. terraform init
4. terraform plan
5. terraform apply

## What This Creates
| Resource | Details |
|---|---|
| Azure Private Link endpoint | Private connectivity from your VNet to Atlas |
| Azure Key Vault encryption at rest | Atlas data encrypted with your Key Vault key |
| Azure service principal (Cloud Provider Access) | Atlas accesses Key Vault and Blob Storage |
| Blob Storage backup export | Atlas snapshots exported to Azure Blob container |

## Useful Links
- Module:        https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-azure/mongodbatlas/latest
- Private Link:  https://www.mongodb.com/docs/atlas/security-private-endpoint/
- CMEK (Azure):  https://www.mongodb.com/docs/atlas/security-azure-kms/
- Backup export: https://www.mongodb.com/docs/atlas/backup/cloud-backup/export/
```

---

## Safety Rules

- **Never hardcode credentials.** All sensitive values must be `sensitive = true` variables.
- **No write operations without confirmation.** If MCP is connected, only read non-sensitive data. Never call create/update/delete MCP tools.
- **Do not recreate the existing cluster.** This configuration only adds hardening resources.
- **Remind about `.gitignore`.** Always include it in Next Steps.

---

## Out of Scope

| Request | Resource |
|---|---|
| Creating a new Atlas cluster from scratch | `atlas-terraform-getting-started` skill |
| AWS PrivateLink, KMS, or S3 integration | `atlas-terraform-aws-harden` skill |
| GCP Private Service Connect or Cloud KMS | `atlas-terraform-gcp-harden` skill |
| Atlas Search / Vector Search | Atlas Search Terraform resource docs |
| Importing existing Terraform state | `terraform import` + provider resource docs |
