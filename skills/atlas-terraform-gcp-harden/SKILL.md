---
name: atlas-terraform-gcp-harden
description: >-
  Use this skill when a user has an existing MongoDB Atlas cluster and wants to harden it
  with GCP security features using Terraform: GCP Private Service Connect endpoints, GCP
  Cloud KMS customer-managed encryption at rest (CMEK), GCP service account for Cloud
  Provider Access, and backup export to Google Cloud Storage (GCS). Triggers on: "add
  Private Service Connect to my Atlas cluster", "enable GCP Cloud KMS encryption Atlas",
  "harden Atlas cluster GCP Terraform", "Atlas GCP private endpoint Terraform", "backup
  export GCS Atlas Terraform", "Atlas GCP service account Cloud Provider Access", "secure
  my Atlas cluster GCP". Also triggers when user already ran atlas-terraform-getting-started
  and now wants GCP security hardening.
  Does NOT trigger for: initial Atlas cluster creation (atlas-terraform-getting-started),
  AWS or Azure cloud integrations, Atlas Search, Vector Search, or general MongoDB querying.
allowed-tools: mcp__MongoDB__*, mcp__plugin_terraform_terraform__get_latest_provider_version, WebSearch, Bash(gh *), Bash(terraform *), Bash(mkdir *), Bash(rm -rf /tmp/atlas-tf-validate-*)
---

# MongoDB Atlas Terraform — GCP Hardening

You generate complete, ready-to-`terraform apply` Terraform configurations that add GCP security
hardening to an existing Atlas cluster using the official
`terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas` Landing Zone module.
Follow this workflow in order.

---

## Step 0: Module Disclosure (Always First)

Before asking any questions, show:

> I'll generate your GCP hardening configuration using the official [MongoDB Atlas GCP Landing Zone
> Module](https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas/latest),
> maintained by MongoDB. This adds GCP Private Service Connect, Cloud KMS encryption at rest,
> GCP service account Cloud Provider Access, and GCS backup export to your existing Atlas cluster.
>
> **Note:** This module is in Public Preview (v0). It is officially supported by MongoDB but
> upgrades from v0 → v1 may require manual migration steps.

---

## Step 1: Resolve Latest Versions

Fetch versions before generating HCL. Never hardcode them.

### 1a: mongodbatlas provider

Try in order until one succeeds:
1. `mcp__plugin_terraform_terraform__get_latest_provider_version`: namespace `mongodb`, type `mongodbatlas`
2. `Bash`: `gh api repos/mongodb/terraform-provider-mongodbatlas/releases/latest --jq '.tag_name'`
3. `WebSearch`: query `mongodb/mongodbatlas terraform provider latest release site:github.com`

Strip the leading `v`. Constraint: `~> 2.0`.

### 1b: atlas-gcp module

Try in order:
1. `Bash`: `gh api repos/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/releases/latest --jq '.tag_name'`
2. `WebSearch` (fallback if gh fails): query `terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas terraform registry latest version`

Constraint: `~> 0.1`. Public Preview module.

### 1c: Google provider

Requires `>= 6.0`. Use constraint `~> 6.0`. No version resolution needed.

### 1d: Inspect atlas-gcp module interface

Fetch the module's actual variable definitions from GitHub before generating any HCL:

```bash
gh api repos/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/contents/variables.tf --jq '.content' | base64 -d
```

Read the output and record every declared variable name. In Step 3 (File 3: main.tf), pass **only** arguments whose names appear in this file. Do not use any argument name absent from the fetched `variables.tf`. If the command fails, proceed with the template in Step 3 but flag to the user that the module interface could not be verified and they should check the [module inputs](https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas/latest?tab=inputs) manually.

---

## Step 2: Gather User Inputs

Ask questions in sequence. Stop after each answer.

### Q1 — Atlas Project ID

> "What is your Atlas Project ID?"

If MCP is connected: call `mcp__MongoDB__atlas-list-projects` and present the list.
Store as `USER_ATLAS_PROJECT_ID`.

### Q2 — Cluster Name

> "What is the name of your existing Atlas cluster?"

If MCP is connected: call `mcp__MongoDB__atlas-list-clusters` with the project ID and present the list.
Store as `USER_CLUSTER_NAME`.

### Q3 — Region

> "What region is your Atlas cluster in? Please provide both:
> - Atlas format (e.g. CENTRAL_US, EASTERN_US, WESTERN_EUROPE)
> - GCP region format (e.g. us-central1, us-east1, europe-west1)"

Store as `USER_ATLAS_REGION` and `USER_GCP_REGION`.

### Q4 — GCP Project

> "What is your GCP project ID?"

Store as `USER_GCP_PROJECT_ID`.

### Q5 — GCP Networking

> "Do you have an existing GCP subnetwork for Private Service Connect, or should I create a new network and subnetwork?"

**Option A — Bring Your Own (BYO):**
- Ask: "What is the subnetwork self-link? (format: projects/PROJECT/regions/REGION/subnetworks/NAME)"
- Store as `USER_SUBNETWORK_SELF_LINK`. Set `NETWORKING = byo`.

**Option B — Create New:**
- Ask: "What CIDR range for the new subnetwork? (e.g. 10.0.0.0/24)"
- Store as `USER_SUBNET_CIDR`. Set `NETWORKING = create`.

### Q6 — Cloud KMS Encryption

> "Do you have an existing GCP Cloud KMS key version for encryption at rest, or should I create a new one via the module?"

**BYO:** Ask: "What is the KMS key version resource ID? (format: projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY/cryptoKeyVersions/VERSION)"
Store as `USER_KMS_KEY_VERSION_RESOURCE_ID`. Set `KMS = byo`.

**Create:** Set `KMS = create`. The module creates the key ring, key, and version automatically.

### Q7 — GCS Backup Export

> "Do you have an existing GCS bucket for Atlas backup export, or should I create a new one via the module?"

**BYO:** Ask: "What is the GCS bucket name?"
Store as `USER_GCS_BUCKET_NAME`. Set `GCS = byo`.

**Create:** Set `GCS = create`. The module creates the bucket automatically.

---

## Step 3: Generate the 5 Files

Substitute all USER_* placeholders with collected answers before rendering.

For `terraform.tfvars.example`, activate only the networking block matching Q5 and delete the other. Do the same for KMS (Q6) and GCS (Q7) blocks.

---

### File 1: `versions.tf`

```hcl
terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.0"  # resolved: MONGODBATLAS_VERSION
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
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
  description = "Atlas region (e.g. CENTRAL_US)."
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID."
  type        = string
}

variable "gcp_region" {
  description = "GCP region (e.g. us-central1)."
  type        = string
}
```

**If `NETWORKING = byo`**, append:
```hcl
variable "subnetwork_self_link" {
  description = "Existing GCP subnetwork self-link for Private Service Connect."
  type        = string
}
```

**If `NETWORKING = create`**, append:
```hcl
variable "subnet_cidr" {
  description = "CIDR range for the new GCP subnetwork (e.g. 10.0.0.0/24)."
  type        = string
}
```

**If `KMS = byo`**, append:
```hcl
variable "kms_key_version_resource_id" {
  description = "GCP Cloud KMS key version resource ID for Atlas encryption at rest."
  type        = string
}
```

**If `GCS = byo`**, append:
```hcl
variable "gcs_bucket_name" {
  description = "Existing GCS bucket name for Atlas backup export."
  type        = string
}
```

---

### File 3: `main.tf`

⚠️ **Use the interface from Step 1d.** Generate the `module "atlas_gcp"` block using **only** argument names that appeared in the fetched `variables.tf`. Verify every argument name against the fetched interface and omit any that are not declared there. Do not assume argument names: if `cluster_name` or `region` are absent from the fetched variables, do not include them.

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# --- NETWORKING = create only: include google_compute_network + google_compute_subnetwork resources ---
resource "google_compute_network" "atlas" {
  name                    = "atlas-harden-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "atlas" {
  name          = "atlas-harden-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.atlas.id
}
# --- end NETWORKING = create block ---

module "atlas_gcp" {
  source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version = "~> 0.1"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  # Creates a GCP service account for Atlas Cloud Provider Access (KMS + GCS permissions) with module defaults.
  cloud_provider_access = {}

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnetwork = SUBNETWORK_PLACEHOLDER
    }
  ]

  encryption    = KMS_PLACEHOLDER
  backup_export = GCS_PLACEHOLDER
}
```

⚠️ **Combination rules:** Replace each placeholder based on user answers.

| Choice | Placeholder | Substitute with |
|---|---|---|
| NETWORKING = byo | `SUBNETWORK_PLACEHOLDER` | `var.subnetwork_self_link` |
| NETWORKING = create | `SUBNETWORK_PLACEHOLDER` | `google_compute_subnetwork.atlas.self_link` |
| NETWORKING = create | google_compute_network + google_compute_subnetwork resources | **keep** |
| NETWORKING = byo | google_compute_network + google_compute_subnetwork resources | **remove** |
| KMS = byo | `KMS_PLACEHOLDER` | `{ enabled = true, key_version_resource_id = var.kms_key_version_resource_id }` |
| KMS = create | `KMS_PLACEHOLDER` | `{ enabled = true, create_kms_key = { enabled = true } }` |
| GCS = byo | `GCS_PLACEHOLDER` | `{ enabled = true, bucket_name = var.gcs_bucket_name }` |
| GCS = create | `GCS_PLACEHOLDER` | `{ enabled = true, create_bucket = { enabled = true } }` |

---

### File 4: `outputs.tf`

```hcl
output "privatelink_endpoint" {
  description = "Atlas Private Service Connect endpoint details."
  value       = module.atlas_gcp.privatelink
}

output "encryption_at_rest_provider" {
  description = "Atlas encryption at rest provider configuration."
  value       = module.atlas_gcp.encryption_at_rest_provider
}

output "cloud_provider_access_service_account" {
  description = "Atlas Cloud Provider Access GCP service account details."
  value       = module.atlas_gcp.role_id
}

output "backup_export_bucket_id" {
  description = "Atlas backup export GCS bucket ID."
  value       = module.atlas_gcp.export_bucket_id
}
```

If `NETWORKING = create`, append:

```hcl
output "network_id" {
  description = "ID of the created GCP network."
  value       = google_compute_network.atlas.id
}

output "subnetwork_self_link" {
  description = "Self-link of the created GCP subnetwork."
  value       = google_compute_subnetwork.atlas.self_link
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
project_id   = "USER_ATLAS_PROJECT_ID"
cluster_name = "USER_CLUSTER_NAME"

# Regions
atlas_region = "USER_ATLAS_REGION"  # e.g. CENTRAL_US
gcp_region   = "USER_GCP_REGION"    # e.g. us-central1

# GCP
gcp_project_id = "USER_GCP_PROJECT_ID"

# --- Networking: keep only one block, delete the other ---

# BYO path: existing subnetwork self-link
subnetwork_self_link = "projects/USER_GCP_PROJECT_ID/regions/USER_GCP_REGION/subnetworks/SUBNET_NAME"

# Create path: delete subnetwork_self_link above and keep this
subnet_cidr = "10.0.0.0/24"

# --- KMS Encryption: keep only the block matching your Q6 answer ---

# BYO path: existing Cloud KMS key version resource ID
kms_key_version_resource_id = "projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY/cryptoKeyVersions/VERSION"

# Create path: remove kms_key_version_resource_id above; module creates key automatically

# --- GCS Backup Export: keep only the block matching your Q7 answer ---

# BYO path: existing GCS bucket
gcs_bucket_name = "<replace-me>"

# Create path: remove gcs_bucket_name above; module creates bucket automatically
```

Replace all USER_* with actual values from Q1–Q7. Pre-populate known values if MCP is connected.

---

## Step 4: Validate the Generated Configuration

Before presenting files to the user, validate the HCL.

1. Create temp directory:

   ```bash
   mkdir -p /tmp/atlas-tf-validate-tmp
   ```

2. Write versions.tf, variables.tf, main.tf, and outputs.tf to `/tmp/atlas-tf-validate-tmp/`. Omit terraform.tfvars.example — it is not valid HCL.

3. Initialize without backend:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp init -backend=false -no-color
   ```

4. Validate:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp validate -no-color
   ```

5. If output **contains** `Success! The configuration is valid.` → present files and proceed to Step 5.
   If validation fails → read error, fix the affected file, and re-validate. If the same error persists after two fix attempts, present the files with a note that HCL validation could not be completed.

6. Always clean up:

   ```bash
   rm -rf /tmp/atlas-tf-validate-tmp
   ```

---

## Step 5: Post-Generation Block

After presenting all 5 files, always append:

```
## Next Steps

1. Copy `terraform.tfvars.example` → `terraform.tfvars` and fill in your credentials.
   Add to `.gitignore`:
     terraform.tfvars
     .terraform/
     *.tfstate
     *.tfstate.backup

2. Authenticate with GCP (if not already):
   gcloud auth application-default login

3. Initialize Terraform:
   terraform init

4. Review:
   terraform plan

5. Apply:
   terraform apply

## What This Creates

| Resource | Details |
|---|---|
| GCP Private Service Connect endpoint | Private connectivity from your VPC to Atlas — no public internet |
| GCP Cloud KMS encryption at rest | All Atlas data encrypted with your Cloud KMS key |
| GCP service account (Cloud Provider Access) | Atlas uses this to access KMS and GCS |
| GCS backup export | Atlas snapshots exported to your GCS bucket |

## Useful Links

- atlas-gcp module:      https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas/latest
- Atlas Private Link:   https://www.mongodb.com/docs/atlas/security-private-endpoint/
- Atlas CMEK (GCP):     https://www.mongodb.com/docs/atlas/security-gcp-kms/
- Atlas backup export:  https://www.mongodb.com/docs/atlas/backup/cloud-backup/export/
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
| Azure Private Link or Key Vault integration | `atlas-terraform-azure-harden` skill |
| Atlas Search / Vector Search | Atlas Search Terraform resource docs |
| Importing existing Terraform state | `terraform import` + provider resource docs |
