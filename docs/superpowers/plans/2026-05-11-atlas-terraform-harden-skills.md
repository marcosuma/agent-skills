# Atlas Terraform Harden Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 3 cloud-specific "harden existing Atlas cluster" skills (AWS, Azure, GCP) and retrofit the getting-started skill with a `terraform validate` step.

**Architecture:** Each harden skill follows a 6-step workflow: module disclosure → version resolution → 6 user questions → 5-file generation (versions.tf, variables.tf, main.tf, outputs.tf, terraform.tfvars.example) → HCL validation in temp dir → post-generation next steps. Skills support two networking paths: BYO existing cloud networking or create new VPC/VNet/network using native provider resources.

**Tech Stack:** Markdown SKILL.md files, skill-validator CLI, atlas-aws v0.3.0 / atlas-azure v0.3.0 / atlas-gcp v0.1.0 Landing Zone modules (Terraform Registry), hashicorp/aws ~> 6.0 / azurerm ~> 4.0 + azuread ~> 2.0 / google ~> 6.0 native providers for networking creation.

---

### Task 1: Retrofit atlas-terraform-getting-started with terraform validate

**Files:**
- Modify: `skills/atlas-terraform-getting-started/SKILL.md`

- [ ] **Step 1: Add validate-related tools to allowed-tools**

Edit line 13 of `skills/atlas-terraform-getting-started/SKILL.md`. Change:

```
allowed-tools: mcp__MongoDB__*, mcp__plugin_terraform_terraform__get_latest_provider_version, WebSearch, Bash(gh *)
```

To:

```
allowed-tools: mcp__MongoDB__*, mcp__plugin_terraform_terraform__get_latest_provider_version, WebSearch, Bash(gh *), Bash(terraform *), Bash(mkdir *), Bash(rm -rf /tmp/atlas-tf-validate-*)
```

- [ ] **Step 2: Insert Step 4 (validate) between the generate and post-generation sections**

Find the line `## Step 4: Post-Generation Block` and insert the following block immediately before it. Then rename the heading from `## Step 4: Post-Generation Block` to `## Step 5: Post-Generation Block`.

Insert this block:

```markdown
## Step 4: Validate the Generated Configuration

Before presenting the files to the user, validate the HCL to catch syntax errors.

1. Create a temp directory:

   ```bash
   mkdir -p /tmp/atlas-tf-validate-tmp
   ```

2. Write versions.tf, variables.tf, main.tf, and outputs.tf to `/tmp/atlas-tf-validate-tmp/`. Omit `terraform.tfvars.example` — it is not valid HCL.

3. Initialize without backend (downloads providers and modules for schema validation — takes ~30 s):

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp init -backend=false -no-color
   ```

4. Validate:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp validate -no-color
   ```

5. If output is `Success! The configuration is valid.` → proceed to Step 5.
   If validation fails → read the error, fix the affected generated file, and re-validate before presenting anything to the user.

6. Always clean up:

   ```bash
   rm -rf /tmp/atlas-tf-validate-tmp
   ```
```

- [ ] **Step 3: Run skill-validator**

```bash
./tools/validate-skills.sh skills/atlas-terraform-getting-started/
```

Expected: `Validation passed` with no errors.

- [ ] **Step 4: Commit**

```bash
git add skills/atlas-terraform-getting-started/SKILL.md
git commit -m "feat(atlas-terraform-getting-started): add terraform validate step after file generation"
```

---

### Task 2: Create atlas-terraform-aws-harden SKILL.md

**Files:**
- Create: `skills/atlas-terraform-aws-harden/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

Create `skills/atlas-terraform-aws-harden/SKILL.md` with this exact content:

````markdown
---
name: atlas-terraform-aws-harden
description: >-
  Use this skill when a user has an existing MongoDB Atlas cluster and wants to harden it
  with AWS security features using Terraform: AWS PrivateLink private endpoints, AWS KMS
  customer-managed encryption at rest (CMEK), IAM role for Cloud Provider Access, and backup
  export to Amazon S3. Triggers on: "add PrivateLink to my Atlas cluster on AWS", "enable
  CMEK encryption Atlas AWS", "harden Atlas cluster AWS Terraform", "Atlas AWS private
  endpoint Terraform", "backup export S3 Atlas Terraform", "Cloud Provider Access IAM role
  Atlas", "secure my Atlas cluster AWS". Also triggers when user already ran
  atlas-terraform-getting-started and now wants to add AWS security hardening.
  Does NOT trigger for: initial Atlas cluster creation (atlas-terraform-getting-started),
  Azure or GCP cloud integrations, Atlas Search, Vector Search, or general MongoDB querying.
allowed-tools: mcp__MongoDB__*, mcp__plugin_terraform_terraform__get_latest_provider_version, WebSearch, Bash(gh *), Bash(terraform *), Bash(mkdir *), Bash(rm -rf /tmp/atlas-tf-validate-*)
---

# MongoDB Atlas Terraform — AWS Hardening

You generate complete, ready-to-`terraform apply` Terraform configurations that add AWS security
hardening to an existing Atlas cluster using the official
`terraform-mongodbatlas-modules/atlas-aws/mongodbatlas` Landing Zone module.
Follow this workflow in order.

---

## Step 0: Module Disclosure (Always First)

Before asking any questions, show:

> I'll generate your AWS hardening configuration using the official [MongoDB Atlas AWS Landing Zone
> Module](https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-aws/mongodbatlas/latest),
> maintained by MongoDB. This adds AWS PrivateLink, KMS encryption at rest, IAM Cloud Provider
> Access, and S3 backup export to your existing Atlas cluster.
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

### 1b: atlas-aws module

Try in order:
1. `WebSearch`: query `terraform-mongodbatlas-modules/atlas-aws/mongodbatlas terraform registry latest version`
2. `Bash`: `gh api repos/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-aws/releases/latest --jq '.tag_name'`

Constraint: `~> 0.3`. Public Preview module.

### 1c: AWS provider

Requires `>= 6.0`. Use constraint `~> 6.0`. No version resolution needed.

---

## Step 2: Gather User Inputs

Ask questions in sequence. Stop after each answer before asking the next.

### Q1 — Atlas Project ID

> "What is your Atlas Project ID?"

If MCP is connected: call `mcp__MongoDB__atlas-list-projects` and present the list.
Store as `USER_PROJECT_ID`.

### Q2 — Cluster Name

> "What is the name of your existing Atlas cluster?"

If MCP is connected: call `mcp__MongoDB__atlas-list-clusters` with the project ID and present the list.
Store as `USER_CLUSTER_NAME`.

### Q3 — Region

> "What region is your Atlas cluster in? Please provide both:
> - Atlas format (e.g. US_EAST_1, EU_WEST_1, AP_SOUTHEAST_2)
> - AWS provider format (e.g. us-east-1, eu-west-1, ap-southeast-2)"

Store as `USER_ATLAS_REGION` and `USER_AWS_REGION`.

### Q4 — AWS Networking

> "Do you have existing AWS networking (VPC + subnets) you want to use for PrivateLink, or should I generate new AWS networking resources?"

**Option A — Bring Your Own (BYO):**
- Ask: "What are your existing subnet IDs for Atlas PrivateLink? (comma-separated, e.g. subnet-abc123,subnet-def456)"
- Store as list `USER_SUBNET_IDS`. Set `NETWORKING = byo`.

**Option B — Create New:**
- Ask: "What CIDR block for the new VPC? (e.g. 10.0.0.0/16)"
- Ask: "Which availability zones should subnets span? (comma-separated, e.g. us-east-1a,us-east-1b)"
- Store as `USER_VPC_CIDR` and `USER_AZS`. Set `NETWORKING = create`.

### Q5 — KMS Encryption

> "Do you have an existing AWS KMS key for encryption at rest, or should I create a new one via the module?"

**BYO:** Ask: "What is the KMS key ARN?" → store as `USER_KMS_ARN`. Set `KMS = byo`.
**Create:** Set `KMS = create`. The module creates the key automatically.

### Q6 — S3 Backup Export

> "Do you have an existing S3 bucket for Atlas backup export, or should I create a new one via the module?"

**BYO:** Ask: "What is the S3 bucket name?" → store as `USER_S3_BUCKET`. Set `S3 = byo`.
**Create:** Set `S3 = create`. The module creates the bucket automatically.

---

## Step 3: Generate the 5 Files

Substitute all USER_* placeholders with collected answers before rendering.

---

### File 1: `versions.tf`

```hcl
terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 2.0"  # resolved: MONGODBATLAS_VERSION
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.9"
}
```

Replace `MONGODBATLAS_VERSION` with the version resolved in Step 1a.

---

### File 2a: `variables.tf` — when `NETWORKING = byo`

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
  description = "Atlas Project ID. Atlas UI → Project Settings → Project ID."
  type        = string
}

variable "cluster_name" {
  description = "Name of the existing Atlas cluster to harden."
  type        = string
}

variable "atlas_region" {
  description = "Atlas region name (e.g. US_EAST_1)."
  type        = string
}

variable "aws_region" {
  description = "AWS provider region (e.g. us-east-1)."
  type        = string
}

variable "subnet_ids" {
  description = "Existing AWS subnet IDs for Atlas PrivateLink endpoints."
  type        = list(string)
}
```

If `KMS = byo`, append:

```hcl
variable "kms_key_arn" {
  description = "Existing AWS KMS key ARN for Atlas encryption at rest."
  type        = string
}
```

If `S3 = byo`, append:

```hcl
variable "s3_bucket_name" {
  description = "Existing S3 bucket name for Atlas backup export."
  type        = string
}
```

---

### File 2b: `variables.tf` — when `NETWORKING = create`

Same as File 2a but replace the `subnet_ids` variable with:

```hcl
variable "vpc_cidr" {
  description = "CIDR block for the new VPC (e.g. 10.0.0.0/16)."
  type        = string
  default     = "USER_VPC_CIDR"
}

variable "availability_zones" {
  description = "AWS availability zones for subnets."
  type        = list(string)
  default     = ["USER_AZ_1", "USER_AZ_2"]
}
```

Apply the same KMS and S3 conditional appends as File 2a.

---

### File 3a: `main.tf` — `NETWORKING = byo`, `KMS = byo`, `S3 = byo`

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "aws" {
  region = var.aws_region
}

module "atlas_aws" {
  source  = "terraform-mongodbatlas-modules/atlas-aws/mongodbatlas"
  version = "~> 0.3"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnet_ids = var.subnet_ids
    }
  ]

  cloud_provider_access = {}

  encryption = {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  backup_export = {
    enabled     = true
    bucket_name = var.s3_bucket_name
  }
}
```

---

### File 3b: `main.tf` — `NETWORKING = byo`, `KMS = create`, `S3 = create`

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "aws" {
  region = var.aws_region
}

module "atlas_aws" {
  source  = "terraform-mongodbatlas-modules/atlas-aws/mongodbatlas"
  version = "~> 0.3"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnet_ids = var.subnet_ids
    }
  ]

  cloud_provider_access = {}

  encryption = {
    enabled        = true
    create_kms_key = { enabled = true }
  }

  backup_export = {
    enabled          = true
    create_s3_bucket = { enabled = true }
  }
}
```

---

### File 3c: `main.tf` — `NETWORKING = create`, `KMS = create`, `S3 = create`

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "atlas" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "atlas-harden-vpc"
  }
}

resource "aws_subnet" "atlas" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.atlas.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "atlas-harden-subnet-${count.index}"
  }
}

module "atlas_aws" {
  source  = "terraform-mongodbatlas-modules/atlas-aws/mongodbatlas"
  version = "~> 0.3"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnet_ids = aws_subnet.atlas[*].id
    }
  ]

  cloud_provider_access = {}

  encryption = {
    enabled        = true
    create_kms_key = { enabled = true }
  }

  backup_export = {
    enabled          = true
    create_s3_bucket = { enabled = true }
  }
}
```

---

### File 3d: `main.tf` — `NETWORKING = create`, `KMS = byo`, `S3 = byo`

Same as File 3c but replace the `encryption` and `backup_export` blocks:

```hcl
  encryption = {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  backup_export = {
    enabled     = true
    bucket_name = var.s3_bucket_name
  }
```

---

⚠️ **Combination rule:** Choose the main.tf variant that matches the user's answers.
- Networking: `subnet_ids = var.subnet_ids` (BYO) or `subnet_ids = aws_subnet.atlas[*].id` (create)
- KMS: `kms_key_arn = var.kms_key_arn` (BYO) or `create_kms_key = { enabled = true }` (create)
- S3: `bucket_name = var.s3_bucket_name` (BYO) or `create_s3_bucket = { enabled = true }` (create)

---

### File 4: `outputs.tf`

```hcl
output "privatelink_endpoint" {
  description = "Atlas PrivateLink endpoint details."
  value       = module.atlas_aws.privatelink
}

output "encryption_at_rest_provider" {
  description = "Atlas encryption at rest provider configuration."
  value       = module.atlas_aws.encryption_at_rest_provider
}

output "cloud_provider_access_role_id" {
  description = "Atlas Cloud Provider Access IAM role ID."
  value       = module.atlas_aws.role_id
}

output "backup_export_bucket_id" {
  description = "Atlas backup export bucket ID."
  value       = module.atlas_aws.export_bucket_id
}
```

If `NETWORKING = create`, append:

```hcl
output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.atlas.id
}

output "subnet_ids" {
  description = "IDs of the created subnets."
  value       = aws_subnet.atlas[*].id
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

# Regions
atlas_region = "USER_ATLAS_REGION"   # e.g. US_EAST_1
aws_region   = "USER_AWS_REGION"     # e.g. us-east-1

# --- Networking (choose one path) ---

# BYO path: existing subnet IDs
subnet_ids = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]

# Create path: uncomment and remove subnet_ids above
# vpc_cidr           = "10.0.0.0/16"
# availability_zones = ["USER_AZ_1", "USER_AZ_2"]

# --- KMS Encryption (choose one path) ---

# BYO path: existing KMS key ARN
kms_key_arn = "<replace-me>"

# Create path: remove kms_key_arn above; module creates the key automatically

# --- S3 Backup Export (choose one path) ---

# BYO path: existing S3 bucket
s3_bucket_name = "<replace-me>"

# Create path: remove s3_bucket_name above; module creates the bucket automatically
```

Replace all `USER_*` with actual values from Q1–Q6. If MCP is connected, pre-populate `project_id` and `cluster_name`.

---

## Step 4: Validate the Generated Configuration

Before presenting the files to the user, validate the HCL.

1. Create temp directory:

   ```bash
   mkdir -p /tmp/atlas-tf-validate-tmp
   ```

2. Write versions.tf, variables.tf, main.tf, and outputs.tf to `/tmp/atlas-tf-validate-tmp/`. Omit terraform.tfvars.example.

3. Initialize without backend:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp init -backend=false -no-color
   ```

4. Validate:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp validate -no-color
   ```

5. If `Success! The configuration is valid.` → present files to user and proceed to Step 5.
   If validation fails → read the error, fix the affected file, and re-validate.

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
   Add to `.gitignore` to avoid committing secrets:
     terraform.tfvars
     .terraform/
     *.tfstate
     *.tfstate.backup

2. Initialize Terraform (downloads providers and the atlas-aws module):
   terraform init

3. Review what will be created:
   terraform plan

4. Apply:
   terraform apply

## What This Creates

| Resource | Details |
|---|---|
| AWS PrivateLink endpoint | Private connectivity from your VPC to Atlas — no traffic over public internet |
| AWS KMS encryption at rest | All Atlas data encrypted with your KMS key |
| IAM role (Cloud Provider Access) | Atlas assumes this role to access KMS and S3 |
| S3 backup export | Atlas snapshots automatically exported to S3 |

## Useful Links

- atlas-aws module:     https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-aws/mongodbatlas/latest
- Atlas PrivateLink:   https://www.mongodb.com/docs/atlas/security-private-endpoint/
- Atlas CMEK:          https://www.mongodb.com/docs/atlas/security-kms-encryption/
- Atlas backup export: https://www.mongodb.com/docs/atlas/backup/cloud-backup/export/
- Cloud Provider Access: https://www.mongodb.com/docs/atlas/security/set-up-unified-aws-access/
```

---

## Safety Rules

- **Never hardcode credentials.** All sensitive values must be declared as `sensitive = true` variables.
- **No write operations without confirmation.** If MCP is connected, only read non-sensitive data (project ID, cluster name). Never call create/update/delete MCP tools.
- **Do not recreate the existing cluster.** This configuration only adds hardening resources — it does not modify or recreate the cluster itself.
- **Remind about `.gitignore`.** Always include it in the Next Steps block.

---

## Out of Scope

| Request | Resource |
|---|---|
| Creating a new Atlas cluster from scratch | `atlas-terraform-getting-started` skill |
| Azure PrivateLink, Key Vault, or Blob Storage integration | `atlas-terraform-azure-harden` skill |
| GCP Private Service Connect or Cloud KMS integration | `atlas-terraform-gcp-harden` skill |
| Atlas Search / Vector Search index management | Atlas Search Terraform resource docs |
| Importing existing Terraform state | `terraform import` + provider resource docs |
| General Terraform errors unrelated to Atlas | HashiCorp Terraform docs |
````

- [ ] **Step 2: Run skill-validator**

```bash
./tools/validate-skills.sh skills/atlas-terraform-aws-harden/
```

Expected: `Validation passed` with no errors.

- [ ] **Step 3: Commit**

```bash
git add skills/atlas-terraform-aws-harden/SKILL.md
git commit -m "feat: add atlas-terraform-aws-harden skill"
```

---

### Task 3: Create atlas-terraform-azure-harden SKILL.md

**Files:**
- Create: `skills/atlas-terraform-azure-harden/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

Create `skills/atlas-terraform-azure-harden/SKILL.md` with this exact content:

````markdown
---
name: atlas-terraform-azure-harden
description: >-
  Use this skill when a user has an existing MongoDB Atlas cluster and wants to harden it
  with Azure security features using Terraform: Azure Private Link endpoints, Azure Key Vault
  customer-managed encryption at rest (CMEK), Azure service principal for Cloud Provider
  Access, and backup export to Azure Blob Storage. Triggers on: "add Private Link to my
  Atlas cluster on Azure", "enable Azure Key Vault encryption Atlas", "harden Atlas cluster
  Azure Terraform", "Atlas Azure private endpoint Terraform", "backup export Azure Blob
  Atlas", "Atlas Azure Key Vault CMEK", "secure my Atlas cluster Azure". Also triggers when
  user already ran atlas-terraform-getting-started and now wants Azure security hardening.
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

> "What is your Atlas Project ID?"

If MCP is connected: call `mcp__MongoDB__atlas-list-projects` and present the list.
Store as `USER_PROJECT_ID`.

### Q2 — Cluster Name

> "What is the name of your existing Atlas cluster?"

If MCP is connected: call `mcp__MongoDB__atlas-list-clusters` with the project ID.
Store as `USER_CLUSTER_NAME`.

### Q3 — Region and Location

> "What region is your Atlas cluster in? Please provide both:
> - Atlas format (e.g. US_EAST_2, EUROPE_WEST, ASIA_PACIFIC_SOUTHEAST)
> - Azure location format (e.g. eastus2, westeurope, southeastasia)"

Store as `USER_ATLAS_REGION` and `USER_AZURE_LOCATION`.

### Q4 — Azure Subscription and Resource Group

> "What is your Azure Subscription ID?"

Store as `USER_SUBSCRIPTION_ID`.

> "What is the name of your Azure Resource Group for Atlas resources?"

Store as `USER_RESOURCE_GROUP`. This resource group must already exist.

### Q5 — Azure Networking

> "Do you have an existing Azure subnet you want to use for Private Link, or should I create a new VNet and subnet?"

**Option A — Bring Your Own (BYO):**
- Ask: "What is the full subnet resource ID? (e.g. /subscriptions/SUBSCRIPTION_ID/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET/subnets/SUBNET)"
- Store as `USER_SUBNET_ID`. Set `NETWORKING = byo`.

**Option B — Create New:**
- Ask: "What address space for the new VNet? (e.g. 10.0.0.0/16)"
- Ask: "What address prefix for the subnet? (e.g. 10.0.1.0/24)"
- Store as `USER_VNET_ADDRESS_SPACE` and `USER_SUBNET_PREFIX`. Set `NETWORKING = create`.

### Q6 — Key Vault Encryption

> "Do you have an existing Azure Key Vault set up for Atlas CMEK, or should I create a new one?"

**BYO:** Ask:
- "What is the full Key Vault resource ID?"
- "What is the key identifier URI?"
Store as `USER_KEY_VAULT_ID` and `USER_KEY_IDENTIFIER`. Set `KMS = byo`.

**Create:** Ask: "What name should the new Key Vault have? (3–24 characters, globally unique)"
Store as `USER_KEY_VAULT_NAME`. Set `KMS = create`. Module creates the Key Vault in `USER_RESOURCE_GROUP` / `USER_AZURE_LOCATION`.

### Q7 — Blob Storage Backup Export

> "Do you have an existing Azure Storage Account for Atlas backup export, or should I create a new one?"

**BYO:** Ask:
- "What is the full Storage Account resource ID?"
- "What is the container name for backup export?"
Store as `USER_STORAGE_ACCOUNT_ID` and `USER_CONTAINER_NAME`. Set `BLOB = byo`.

**Create:** Ask:
- "What name should the new Storage Account have? (3–24 characters, globally unique, lowercase letters and numbers only)"
- "What container name should be used for backups?"
Store as `USER_STORAGE_ACCOUNT_NAME` and `USER_CONTAINER_NAME`. Set `BLOB = create`. Module creates the account in `USER_RESOURCE_GROUP` / `USER_AZURE_LOCATION`.

---

## Step 3: Generate the 5 Files

Substitute all USER_* placeholders with collected answers.

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

### File 2a: `variables.tf` — when `NETWORKING = byo`

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
  description = "Existing Azure Resource Group name for Atlas resources."
  type        = string
}

variable "subnet_id" {
  description = "Full resource ID of the existing Azure subnet for Private Link."
  type        = string
}
```

If `KMS = byo`, append:

```hcl
variable "key_vault_id" {
  description = "Full resource ID of the existing Azure Key Vault."
  type        = string
}

variable "key_identifier" {
  description = "Azure Key Vault key identifier URI for CMEK."
  type        = string
}
```

If `KMS = create`, append:

```hcl
variable "key_vault_name" {
  description = "Name for the new Azure Key Vault (3–24 chars, globally unique)."
  type        = string
  default     = "USER_KEY_VAULT_NAME"
}
```

If `BLOB = byo`, append:

```hcl
variable "storage_account_id" {
  description = "Full resource ID of the existing Azure Storage Account."
  type        = string
}

variable "backup_container_name" {
  description = "Azure Blob container name for Atlas backup export."
  type        = string
  default     = "USER_CONTAINER_NAME"
}
```

If `BLOB = create`, append:

```hcl
variable "storage_account_name" {
  description = "Name for the new Azure Storage Account (3–24 chars, globally unique, lowercase)."
  type        = string
  default     = "USER_STORAGE_ACCOUNT_NAME"
}

variable "backup_container_name" {
  description = "Azure Blob container name for Atlas backup export."
  type        = string
  default     = "USER_CONTAINER_NAME"
}
```

---

### File 2b: `variables.tf` — when `NETWORKING = create`

Same as File 2a but replace the `subnet_id` variable with:

```hcl
variable "vnet_address_space" {
  description = "Address space for the new Virtual Network (e.g. 10.0.0.0/16)."
  type        = string
  default     = "USER_VNET_ADDRESS_SPACE"
}

variable "subnet_prefix" {
  description = "Address prefix for the subnet (e.g. 10.0.1.0/24)."
  type        = string
  default     = "USER_SUBNET_PREFIX"
}
```

Apply the same conditional appends for KMS and BLOB.

---

### File 3a: `main.tf` — `NETWORKING = byo`, `KMS = byo`, `BLOB = byo`

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

module "atlas_azure" {
  source  = "terraform-mongodbatlas-modules/atlas-azure/mongodbatlas"
  version = "~> 0.3"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  create_service_principal = true

  privatelink_endpoints = [
    {
      region    = var.atlas_region
      subnet_id = var.subnet_id
    }
  ]

  encryption = {
    enabled        = true
    key_vault_id   = var.key_vault_id
    key_identifier = var.key_identifier
  }

  backup_export = {
    enabled            = true
    container_name     = var.backup_container_name
    storage_account_id = var.storage_account_id
  }
}
```

---

### File 3b: `main.tf` — `NETWORKING = byo`, `KMS = create`, `BLOB = create`

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

module "atlas_azure" {
  source  = "terraform-mongodbatlas-modules/atlas-azure/mongodbatlas"
  version = "~> 0.3"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  create_service_principal = true

  privatelink_endpoints = [
    {
      region    = var.atlas_region
      subnet_id = var.subnet_id
    }
  ]

  encryption = {
    enabled = true
    create_key_vault = {
      enabled             = true
      name                = var.key_vault_name
      resource_group_name = var.resource_group_name
      azure_location      = var.azure_location
    }
  }

  backup_export = {
    enabled        = true
    container_name = var.backup_container_name
    create_storage_account = {
      enabled             = true
      name                = var.storage_account_name
      resource_group_name = var.resource_group_name
      azure_location      = var.azure_location
    }
  }
}
```

---

### File 3c: `main.tf` — `NETWORKING = create`, `KMS = create`, `BLOB = create`

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

module "atlas_azure" {
  source  = "terraform-mongodbatlas-modules/atlas-azure/mongodbatlas"
  version = "~> 0.3"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  create_service_principal = true

  privatelink_endpoints = [
    {
      region    = var.atlas_region
      subnet_id = azurerm_subnet.atlas.id
    }
  ]

  encryption = {
    enabled = true
    create_key_vault = {
      enabled             = true
      name                = var.key_vault_name
      resource_group_name = var.resource_group_name
      azure_location      = var.azure_location
    }
  }

  backup_export = {
    enabled        = true
    container_name = var.backup_container_name
    create_storage_account = {
      enabled             = true
      name                = var.storage_account_name
      resource_group_name = var.resource_group_name
      azure_location      = var.azure_location
    }
  }
}
```

---

### File 3d: `main.tf` — `NETWORKING = create`, `KMS = byo`, `BLOB = byo`

Same as File 3c (includes azurerm_virtual_network + azurerm_subnet), but replace `encryption` and `backup_export`:

```hcl
  encryption = {
    enabled        = true
    key_vault_id   = var.key_vault_id
    key_identifier = var.key_identifier
  }

  backup_export = {
    enabled            = true
    container_name     = var.backup_container_name
    storage_account_id = var.storage_account_id
  }
```

---

⚠️ **Combination rule:** Choose the main.tf variant matching user answers.
- Networking: `subnet_id = var.subnet_id` (BYO) or `subnet_id = azurerm_subnet.atlas.id` (create)
- KMS: `key_vault_id + key_identifier` (BYO) or `create_key_vault = { ... }` (create)
- Blob: `storage_account_id + container_name` (BYO) or `create_storage_account = { ... }` (create)

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

# --- Networking (choose one path) ---

# BYO path: existing subnet resource ID
subnet_id = "/subscriptions/SUB/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET/subnets/SUBNET"

# Create path: uncomment and remove subnet_id above
# vnet_address_space = "10.0.0.0/16"
# subnet_prefix      = "10.0.1.0/24"

# --- Key Vault (choose one path) ---

# BYO path: existing Key Vault
# key_vault_id   = "/subscriptions/SUB/resourceGroups/RG/providers/Microsoft.KeyVault/vaults/VAULT"
# key_identifier = "https://VAULT.vault.azure.net/keys/KEY/VERSION"

# Create path: remove key_vault_id / key_identifier above
key_vault_name = "USER_KEY_VAULT_NAME"

# --- Blob Storage Backup Export (choose one path) ---

# BYO path: existing storage account
# storage_account_id    = "/subscriptions/SUB/resourceGroups/RG/providers/Microsoft.Storage/storageAccounts/ACCT"
# backup_container_name = "USER_CONTAINER_NAME"

# Create path: remove storage_account_id above
storage_account_name  = "USER_STORAGE_ACCOUNT_NAME"
backup_container_name = "USER_CONTAINER_NAME"
```

---

## Step 4: Validate the Generated Configuration

Before presenting files to the user, validate the HCL.

1. Create temp directory:

   ```bash
   mkdir -p /tmp/atlas-tf-validate-tmp
   ```

2. Write versions.tf, variables.tf, main.tf, and outputs.tf to `/tmp/atlas-tf-validate-tmp/`. Omit terraform.tfvars.example.

3. Initialize without backend:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp init -backend=false -no-color
   ```

4. Validate:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp validate -no-color
   ```

5. If `Success! The configuration is valid.` → present files and proceed to Step 5.
   If validation fails → read error, fix file, re-validate.

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

2. Authenticate with Azure CLI (if not already):
   az login

3. Initialize Terraform:
   terraform init

4. Review:
   terraform plan

5. Apply:
   terraform apply

## What This Creates

| Resource | Details |
|---|---|
| Azure Private Link endpoint | Private connectivity from your VNet to Atlas — no public internet |
| Azure Key Vault encryption at rest | All Atlas data encrypted with your Key Vault key |
| Azure service principal (Cloud Provider Access) | Atlas uses this to access Key Vault and Blob Storage |
| Blob Storage backup export | Atlas snapshots exported to Azure Blob container |

## Useful Links

- atlas-azure module:   https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-azure/mongodbatlas/latest
- Atlas Private Link:  https://www.mongodb.com/docs/atlas/security-private-endpoint/
- Atlas CMEK (Azure):  https://www.mongodb.com/docs/atlas/security-azure-kms/
- Atlas backup export: https://www.mongodb.com/docs/atlas/backup/cloud-backup/export/
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
````

- [ ] **Step 2: Run skill-validator**

```bash
./tools/validate-skills.sh skills/atlas-terraform-azure-harden/
```

Expected: `Validation passed` with no errors.

- [ ] **Step 3: Commit**

```bash
git add skills/atlas-terraform-azure-harden/SKILL.md
git commit -m "feat: add atlas-terraform-azure-harden skill"
```

---

### Task 4: Create atlas-terraform-gcp-harden SKILL.md

**Files:**
- Create: `skills/atlas-terraform-gcp-harden/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

Create `skills/atlas-terraform-gcp-harden/SKILL.md` with this exact content:

````markdown
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
2. `WebSearch`: query `mongodb/mongodbatlas terraform provider latest release site:github.com`
3. `Bash`: `gh api repos/mongodb/terraform-provider-mongodbatlas/releases/latest --jq '.tag_name'`

Strip the leading `v`. Constraint: `~> 2.0`.

### 1b: atlas-gcp module

Try in order:
1. `WebSearch`: query `terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas terraform registry latest version`
2. `Bash`: `gh api repos/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-gcp/releases/latest --jq '.tag_name'`

Constraint: `~> 0.1`. Public Preview module.

### 1c: Google provider

Requires `>= 6.0`. Constraint: `~> 6.0`. No version resolution needed.

---

## Step 2: Gather User Inputs

Ask questions in sequence. Stop after each answer.

### Q1 — Atlas Project ID

> "What is your Atlas Project ID?"

If MCP is connected: call `mcp__MongoDB__atlas-list-projects` and present the list.
Store as `USER_ATLAS_PROJECT_ID`.

### Q2 — Cluster Name

> "What is the name of your existing Atlas cluster?"

If MCP is connected: call `mcp__MongoDB__atlas-list-clusters` with the project ID.
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

Substitute all USER_* placeholders with collected answers.

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

### File 2a: `variables.tf` — when `NETWORKING = byo`

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

variable "subnetwork_self_link" {
  description = "Existing GCP subnetwork self-link for Private Service Connect."
  type        = string
}
```

If `KMS = byo`, append:

```hcl
variable "kms_key_version_resource_id" {
  description = "GCP Cloud KMS key version resource ID for Atlas encryption at rest."
  type        = string
}
```

If `GCS = byo`, append:

```hcl
variable "gcs_bucket_name" {
  description = "Existing GCS bucket name for Atlas backup export."
  type        = string
}
```

---

### File 2b: `variables.tf` — when `NETWORKING = create`

Same as File 2a but replace the `subnetwork_self_link` variable with:

```hcl
variable "subnet_cidr" {
  description = "CIDR range for the new GCP subnetwork (e.g. 10.0.0.0/24)."
  type        = string
  default     = "USER_SUBNET_CIDR"
}
```

Apply the same conditional appends for KMS and GCS.

---

### File 3a: `main.tf` — `NETWORKING = byo`, `KMS = byo`, `GCS = byo`

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

module "atlas_gcp" {
  source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version = "~> 0.1"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnetwork = var.subnetwork_self_link
    }
  ]

  cloud_provider_access = {}

  encryption = {
    enabled                 = true
    key_version_resource_id = var.kms_key_version_resource_id
  }

  backup_export = {
    enabled     = true
    bucket_name = var.gcs_bucket_name
  }
}
```

---

### File 3b: `main.tf` — `NETWORKING = byo`, `KMS = create`, `GCS = create`

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

module "atlas_gcp" {
  source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version = "~> 0.1"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnetwork = var.subnetwork_self_link
    }
  ]

  cloud_provider_access = {}

  encryption = {
    enabled        = true
    create_kms_key = { enabled = true }
  }

  backup_export = {
    enabled       = true
    create_bucket = { enabled = true }
  }
}
```

---

### File 3c: `main.tf` — `NETWORKING = create`, `KMS = create`, `GCS = create`

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

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

module "atlas_gcp" {
  source  = "terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas"
  version = "~> 0.1"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnetwork = google_compute_subnetwork.atlas.self_link
    }
  ]

  cloud_provider_access = {}

  encryption = {
    enabled        = true
    create_kms_key = { enabled = true }
  }

  backup_export = {
    enabled       = true
    create_bucket = { enabled = true }
  }
}
```

---

### File 3d: `main.tf` — `NETWORKING = create`, `KMS = byo`, `GCS = byo`

Same as File 3c (includes google_compute_network + google_compute_subnetwork), but replace `encryption` and `backup_export`:

```hcl
  encryption = {
    enabled                 = true
    key_version_resource_id = var.kms_key_version_resource_id
  }

  backup_export = {
    enabled     = true
    bucket_name = var.gcs_bucket_name
  }
```

---

⚠️ **Combination rule:** Choose the main.tf variant matching user answers.
- Networking: `subnetwork = var.subnetwork_self_link` (BYO) or `subnetwork = google_compute_subnetwork.atlas.self_link` (create)
- KMS: `key_version_resource_id = var.kms_key_version_resource_id` (BYO) or `create_kms_key = { enabled = true }` (create)
- GCS: `bucket_name = var.gcs_bucket_name` (BYO) or `create_bucket = { enabled = true }` (create)

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

# --- Networking (choose one path) ---

# BYO path: existing subnetwork self-link
subnetwork_self_link = "projects/USER_GCP_PROJECT_ID/regions/USER_GCP_REGION/subnetworks/SUBNET_NAME"

# Create path: uncomment and remove subnetwork_self_link above
# subnet_cidr = "10.0.0.0/24"

# --- KMS Encryption (choose one path) ---

# BYO path: existing Cloud KMS key version resource ID
kms_key_version_resource_id = "projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY/cryptoKeyVersions/VERSION"

# Create path: remove kms_key_version_resource_id above; module creates key automatically

# --- GCS Backup Export (choose one path) ---

# BYO path: existing GCS bucket
gcs_bucket_name = "<replace-me>"

# Create path: remove gcs_bucket_name above; module creates bucket automatically
```

---

## Step 4: Validate the Generated Configuration

Before presenting files to the user, validate the HCL.

1. Create temp directory:

   ```bash
   mkdir -p /tmp/atlas-tf-validate-tmp
   ```

2. Write versions.tf, variables.tf, main.tf, and outputs.tf to `/tmp/atlas-tf-validate-tmp/`. Omit terraform.tfvars.example.

3. Initialize without backend:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp init -backend=false -no-color
   ```

4. Validate:

   ```bash
   terraform -chdir=/tmp/atlas-tf-validate-tmp validate -no-color
   ```

5. If `Success! The configuration is valid.` → present files and proceed to Step 5.
   If validation fails → read error, fix file, re-validate.

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
````

- [ ] **Step 2: Run skill-validator**

```bash
./tools/validate-skills.sh skills/atlas-terraform-gcp-harden/
```

Expected: `Validation passed` with no errors.

- [ ] **Step 3: Commit**

```bash
git add skills/atlas-terraform-gcp-harden/SKILL.md
git commit -m "feat: add atlas-terraform-gcp-harden skill"
```

---

### Task 5: Write eval tests for all 3 harden skills

**Files:**
- Create: `testing/atlas-terraform-aws-harden/evals/evals.json`
- Create: `testing/atlas-terraform-azure-harden/evals/evals.json`
- Create: `testing/atlas-terraform-gcp-harden/evals/evals.json`

- [ ] **Step 1: Create AWS eval file**

```bash
mkdir -p testing/atlas-terraform-aws-harden/evals
```

Write `testing/atlas-terraform-aws-harden/evals/evals.json`:

```json
{
  "skill_name": "atlas-terraform-aws-harden",
  "evals": [
    {
      "id": 1,
      "name": "byo-networking-create-kms-create-s3",
      "prompt": "I have an Atlas cluster called prod-cluster in project 5f3a8b2c1d4e5f6a7b8c9d0e. I want to add AWS PrivateLink, KMS encryption, and S3 backup export using Terraform. I already have subnets subnet-aaa111 and subnet-bbb222 in us-east-1. Let the module create the KMS key and S3 bucket.",
      "expected_output": "Generates 5 files. versions.tf has mongodbatlas ~> 2.0 and aws ~> 6.0. main.tf uses module atlas-aws with subnet_ids = var.subnet_ids (BYO networking). encryption block uses create_kms_key = { enabled = true }. backup_export uses create_s3_bucket = { enabled = true }. variables.tf has subnet_ids variable (list of strings), no kms_key_arn or s3_bucket_name.",
      "expectations": [
        "Shows module disclosure mentioning atlas-aws Landing Zone Module before any questions",
        "Resolves mongodbatlas provider version dynamically (not hardcoded) with constraint ~> 2.0",
        "versions.tf includes aws provider source = 'hashicorp/aws' version ~> 6.0",
        "main.tf uses module source 'terraform-mongodbatlas-modules/atlas-aws/mongodbatlas' version ~> 0.3",
        "privatelink_endpoints uses subnet_ids = var.subnet_ids (BYO path — no aws_vpc or aws_subnet resources)",
        "cloud_provider_access = {} is present (creates IAM role automatically)",
        "encryption block uses create_kms_key = { enabled = true } (no kms_key_arn)",
        "backup_export block uses create_s3_bucket = { enabled = true } (no bucket_name)",
        "variables.tf has subnet_ids as list(string) and does NOT include kms_key_arn or s3_bucket_name",
        "outputs.tf includes privatelink_endpoint, encryption_at_rest_provider, cloud_provider_access_role_id, backup_export_bucket_id",
        "No aws_vpc or aws_subnet resources in main.tf (BYO networking)",
        "terraform.tfvars.example has subnet_ids pre-populated with ['subnet-aaa111', 'subnet-bbb222']",
        "Post-generation block includes .gitignore reminder and terraform init / plan / apply commands",
        "Runs terraform validate before presenting files to user"
      ]
    },
    {
      "id": 2,
      "name": "create-networking-create-kms-create-s3",
      "prompt": "I need to add full AWS security hardening to my Atlas cluster 'dev-cluster' (project ID: abc123def456). I don't have any existing AWS networking — please create a new VPC with CIDR 10.1.0.0/16 across us-east-1a and us-east-1b. Also create a new KMS key and S3 bucket for me.",
      "expected_output": "Generates 5 files. main.tf includes aws_vpc and aws_subnet resources. atlas-aws module uses subnet_ids = aws_subnet.atlas[*].id. encryption uses create_kms_key = { enabled = true }. backup_export uses create_s3_bucket = { enabled = true }. variables.tf has vpc_cidr and availability_zones instead of subnet_ids.",
      "expectations": [
        "main.tf contains resource 'aws_vpc' 'atlas' with cidr_block = var.vpc_cidr and enable_dns_hostnames = true",
        "main.tf contains resource 'aws_subnet' 'atlas' with count = length(var.availability_zones)",
        "cidrsubnet function used for subnet CIDR calculation",
        "module atlas_aws privatelink_endpoints uses subnet_ids = aws_subnet.atlas[*].id",
        "variables.tf has vpc_cidr (default 10.1.0.0/16) and availability_zones (default ['us-east-1a', 'us-east-1b'])",
        "variables.tf does NOT have subnet_ids variable",
        "outputs.tf includes vpc_id = aws_vpc.atlas.id and subnet_ids = aws_subnet.atlas[*].id in addition to module outputs",
        "encryption uses create_kms_key = { enabled = true }",
        "backup_export uses create_s3_bucket = { enabled = true }",
        "Validates HCL before presenting files"
      ]
    },
    {
      "id": 3,
      "name": "byo-all-resources",
      "prompt": "Add AWS hardening to my Atlas cluster 'analytics' in project 111aaa222bbb. I have existing subnets subnet-xyz789 in us-west-2. My existing KMS key ARN is arn:aws:kms:us-west-2:123456789:key/abc-def and my S3 bucket is called my-atlas-backups.",
      "expected_output": "Generates 5 files using all BYO paths. main.tf module uses subnet_ids = var.subnet_ids, kms_key_arn = var.kms_key_arn, bucket_name = var.s3_bucket_name. No aws_vpc/subnet resources. No create_kms_key or create_s3_bucket blocks.",
      "expectations": [
        "main.tf uses subnet_ids = var.subnet_ids (no VPC/subnet resources)",
        "encryption block uses kms_key_arn = var.kms_key_arn (no create_kms_key)",
        "backup_export block uses bucket_name = var.s3_bucket_name (no create_s3_bucket)",
        "variables.tf includes subnet_ids, kms_key_arn, and s3_bucket_name variables",
        "terraform.tfvars.example pre-populates: subnet_ids with ['subnet-xyz789'], kms_key_arn with arn:aws:kms:us-west-2:123456789:key/abc-def, s3_bucket_name with my-atlas-backups",
        "atlas_region and aws_region variables are present (atlas format US_WEST_2 and AWS format us-west-2)"
      ]
    },
    {
      "id": 4,
      "name": "out-of-scope-new-cluster",
      "prompt": "I want to create a new MongoDB Atlas cluster on AWS with PrivateLink enabled from the start.",
      "expected_output": "Explains that creating a new cluster is handled by atlas-terraform-getting-started, not this skill. Directs user to atlas-terraform-getting-started first, then atlas-terraform-aws-harden for security hardening.",
      "expectations": [
        "Does NOT generate any Terraform code for cluster creation",
        "Explains this skill is for hardening an existing cluster, not creating a new one",
        "Mentions atlas-terraform-getting-started as the skill to use first",
        "Suggests using atlas-terraform-aws-harden after the cluster is created"
      ]
    },
    {
      "id": 5,
      "name": "out-of-scope-azure",
      "prompt": "I have an Atlas cluster on Azure. Help me add Azure Private Link and Key Vault encryption using Terraform.",
      "expected_output": "Recognizes this is an Azure request and directs user to atlas-terraform-azure-harden.",
      "expectations": [
        "Does NOT generate AWS Terraform code",
        "Explains this skill is for AWS hardening only",
        "Mentions atlas-terraform-azure-harden as the correct skill for Azure"
      ]
    },
    {
      "id": 6,
      "name": "version-resolution",
      "prompt": "Add AWS PrivateLink and KMS hardening to my Atlas cluster 'test' (project xyz789). I have subnet subnet-111aaa in us-east-1.",
      "expected_output": "Resolves mongodbatlas provider version dynamically before generating code. The HCL comment in versions.tf shows the resolved version number.",
      "expectations": [
        "Attempts to resolve latest mongodbatlas provider version via mcp__plugin_terraform_terraform__get_latest_provider_version, WebSearch, or gh CLI",
        "versions.tf constraint is ~> 2.0 (not a hardcoded patch version)",
        "Comment in versions.tf shows the resolved version number",
        "atlas-aws module version constraint is ~> 0.3",
        "aws provider version constraint is ~> 6.0"
      ]
    }
  ]
}
```

- [ ] **Step 2: Create Azure eval file**

```bash
mkdir -p testing/atlas-terraform-azure-harden/evals
```

Write `testing/atlas-terraform-azure-harden/evals/evals.json`:

```json
{
  "skill_name": "atlas-terraform-azure-harden",
  "evals": [
    {
      "id": 1,
      "name": "byo-subnet-create-kv-create-storage",
      "prompt": "I have an Atlas cluster 'prod' in project abc123. I want to add Azure Private Link, Key Vault encryption, and Blob Storage backup export. My existing subnet is /subscriptions/sub123/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/atlas-subnet in eastus2. Please create a new Key Vault named 'atlas-kv-prod' and a new storage account 'atlasbackupprod' with container 'backups'. My subscription is sub123 and resource group is my-rg.",
      "expected_output": "Generates 5 files. versions.tf has mongodbatlas ~> 2.0, azurerm ~> 4.0, azuread ~> 2.0. main.tf uses atlas-azure module with subnet_id = var.subnet_id (BYO networking), create_key_vault with name 'atlas-kv-prod', create_storage_account with name 'atlasbackupprod'. No VNet/subnet resources.",
      "expectations": [
        "Shows module disclosure for atlas-azure Landing Zone Module",
        "versions.tf includes azurerm ~> 4.0 and azuread ~> 2.0 providers",
        "main.tf has provider 'azurerm' with features {} and provider 'azuread'",
        "module atlas_azure uses create_service_principal = true",
        "privatelink_endpoints uses subnet_id = var.subnet_id (singular, not list)",
        "encryption block uses create_key_vault = { enabled = true, name = 'atlas-kv-prod', resource_group_name = var.resource_group_name, azure_location = var.azure_location }",
        "backup_export uses create_storage_account = { enabled = true, name = 'atlasbackupprod', resource_group_name = var.resource_group_name, azure_location = var.azure_location }",
        "backup_export includes container_name = var.backup_container_name",
        "No azurerm_virtual_network or azurerm_subnet resources (BYO networking)",
        "variables.tf has subnet_id as string (not list), key_vault_name, storage_account_name, backup_container_name",
        "Runs terraform validate before presenting files"
      ]
    },
    {
      "id": 2,
      "name": "create-networking-create-kv-create-storage",
      "prompt": "Help me harden my Atlas cluster 'dev' (project: proj999) on Azure. I don't have any Azure networking yet. Create a VNet with address space 10.2.0.0/16 and subnet 10.2.1.0/24. Also create a Key Vault 'atlas-kv-dev' and storage account 'atlasbackupdev'. Resource group is 'dev-rg', location is eastus2, subscription sub456.",
      "expected_output": "Generates 5 files. main.tf includes azurerm_virtual_network and azurerm_subnet resources. atlas-azure module uses subnet_id = azurerm_subnet.atlas.id.",
      "expectations": [
        "main.tf contains resource 'azurerm_virtual_network' 'atlas' with location = var.azure_location and resource_group_name = var.resource_group_name",
        "main.tf contains resource 'azurerm_subnet' 'atlas' with address_prefixes = [var.subnet_prefix]",
        "module atlas_azure privatelink_endpoints uses subnet_id = azurerm_subnet.atlas.id",
        "variables.tf has vnet_address_space and subnet_prefix instead of subnet_id",
        "outputs.tf includes vnet_id and subnet_id from azurerm resources",
        "create_service_principal = true present in module",
        "create_key_vault and create_storage_account blocks present with required name, resource_group_name, azure_location"
      ]
    },
    {
      "id": 3,
      "name": "byo-keyvault-byo-storage",
      "prompt": "Add Azure hardening to my Atlas cluster 'analytics' (project: ppp111). I already have a subnet /subscriptions/s/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/subnet, Key Vault ID /subscriptions/s/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/my-vault with key identifier https://my-vault.vault.azure.net/keys/atlas-key/version1, and storage account /subscriptions/s/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/myaccount with container 'atlas-exports'.",
      "expected_output": "Generates 5 files using all BYO paths. encryption uses key_vault_id + key_identifier. backup_export uses storage_account_id + container_name.",
      "expectations": [
        "encryption block uses key_vault_id = var.key_vault_id and key_identifier = var.key_identifier (no create_key_vault)",
        "backup_export block uses storage_account_id = var.storage_account_id and container_name = var.backup_container_name (no create_storage_account)",
        "variables.tf includes key_vault_id, key_identifier, storage_account_id, backup_container_name",
        "variables.tf does NOT include key_vault_name or storage_account_name",
        "No azurerm_virtual_network or azurerm_subnet resources"
      ]
    },
    {
      "id": 4,
      "name": "out-of-scope-gcp",
      "prompt": "I want to add GCP Private Service Connect and Cloud KMS to my Atlas cluster using Terraform.",
      "expected_output": "Recognizes this is a GCP request and directs user to atlas-terraform-gcp-harden.",
      "expectations": [
        "Does NOT generate Azure Terraform code",
        "Explains this skill covers Azure hardening only",
        "Mentions atlas-terraform-gcp-harden as the correct skill"
      ]
    }
  ]
}
```

- [ ] **Step 3: Create GCP eval file**

```bash
mkdir -p testing/atlas-terraform-gcp-harden/evals
```

Write `testing/atlas-terraform-gcp-harden/evals/evals.json`:

```json
{
  "skill_name": "atlas-terraform-gcp-harden",
  "evals": [
    {
      "id": 1,
      "name": "byo-subnetwork-create-kms-create-gcs",
      "prompt": "I have an Atlas cluster 'prod-gcp' in project abc123. Add GCP Private Service Connect, Cloud KMS encryption, and GCS backup export. My existing subnetwork self-link is projects/my-gcp-project/regions/us-central1/subnetworks/atlas-subnet. GCP project is my-gcp-project, region us-central1. Let the module create the KMS key and GCS bucket.",
      "expected_output": "Generates 5 files. versions.tf has mongodbatlas ~> 2.0 and google ~> 6.0. main.tf uses atlas-gcp module with subnetwork = var.subnetwork_self_link (BYO). encryption uses create_kms_key = { enabled = true }. backup_export uses create_bucket = { enabled = true }. No google_compute_network or subnetwork resources.",
      "expectations": [
        "Shows module disclosure for atlas-gcp Landing Zone Module",
        "versions.tf includes google provider source = 'hashicorp/google' version ~> 6.0",
        "main.tf uses module source 'terraform-mongodbatlas-modules/atlas-gcp/mongodbatlas' version ~> 0.1",
        "google provider block has project = var.gcp_project_id and region = var.gcp_region",
        "privatelink_endpoints uses subnetwork = var.subnetwork_self_link (BYO path)",
        "cloud_provider_access = {} present (creates GCP service account automatically)",
        "encryption block uses create_kms_key = { enabled = true }",
        "backup_export block uses create_bucket = { enabled = true }",
        "No google_compute_network or google_compute_subnetwork resources",
        "variables.tf has subnetwork_self_link, gcp_project_id, gcp_region",
        "Runs terraform validate before presenting files"
      ]
    },
    {
      "id": 2,
      "name": "create-networking-create-kms-create-gcs",
      "prompt": "Harden my Atlas cluster 'staging-gcp' (project: proj333) on GCP. I have no existing GCP networking. Create a new network and subnet with CIDR 10.3.0.0/24. Also create KMS key and GCS bucket. GCP project is staging-project, region us-east1.",
      "expected_output": "Generates 5 files. main.tf includes google_compute_network and google_compute_subnetwork resources. atlas-gcp module uses subnetwork = google_compute_subnetwork.atlas.self_link.",
      "expectations": [
        "main.tf contains resource 'google_compute_network' 'atlas' with auto_create_subnetworks = false",
        "main.tf contains resource 'google_compute_subnetwork' 'atlas' with ip_cidr_range = var.subnet_cidr and region = var.gcp_region",
        "module atlas_gcp privatelink_endpoints uses subnetwork = google_compute_subnetwork.atlas.self_link",
        "variables.tf has subnet_cidr instead of subnetwork_self_link",
        "outputs.tf includes network_id and subnetwork_self_link from google_compute resources",
        "create_kms_key = { enabled = true } and create_bucket = { enabled = true } present"
      ]
    },
    {
      "id": 3,
      "name": "byo-all-resources",
      "prompt": "Add GCP hardening to Atlas cluster 'data-warehouse' (project: dw123). My subnetwork is projects/my-proj/regions/us-central1/subnetworks/atlas-net. My KMS key version is projects/my-proj/locations/global/keyRings/atlas-ring/cryptoKeys/atlas-key/cryptoKeyVersions/1. My GCS bucket is my-atlas-backups-bucket.",
      "expected_output": "Generates 5 files with all BYO paths. encryption uses key_version_resource_id. backup_export uses bucket_name.",
      "expectations": [
        "encryption block uses key_version_resource_id = var.kms_key_version_resource_id",
        "backup_export block uses bucket_name = var.gcs_bucket_name",
        "No create_kms_key or create_bucket blocks",
        "variables.tf includes kms_key_version_resource_id and gcs_bucket_name",
        "terraform.tfvars.example pre-populates kms_key_version_resource_id and gcs_bucket_name"
      ]
    },
    {
      "id": 4,
      "name": "out-of-scope-aws",
      "prompt": "Add AWS PrivateLink and KMS encryption to my Atlas cluster using Terraform.",
      "expected_output": "Recognizes this is an AWS request and directs user to atlas-terraform-aws-harden.",
      "expectations": [
        "Does NOT generate GCP Terraform code",
        "Explains this skill covers GCP hardening only",
        "Mentions atlas-terraform-aws-harden as the correct skill"
      ]
    }
  ]
}
```

- [ ] **Step 4: Commit**

```bash
git add testing/atlas-terraform-aws-harden/ testing/atlas-terraform-azure-harden/ testing/atlas-terraform-gcp-harden/
git commit -m "test: add eval tests for atlas-terraform harden skills (aws, azure, gcp)"
```

---

### Task 6: Write boundary tests

**Files:**
- Create: `testing/skills-boundaries/atlas-terraform-harden-vs-skills.json`

- [ ] **Step 1: Write the boundary test file**

Write `testing/skills-boundaries/atlas-terraform-harden-vs-skills.json`:

```json
{
  "test_suite": "Atlas Terraform Harden Skills - Skill Invocation Tests",
  "description": "Validates that atlas-terraform-aws-harden, atlas-terraform-azure-harden, and atlas-terraform-gcp-harden trigger on the right prompts and do not conflict with atlas-terraform-getting-started or other skills. Tests boundaries between harden skills and getting-started, natural-language-querying, schema-design, search-and-ai.",
  "version": "1.0",
  "skills_tested": [
    "atlas-terraform-aws-harden",
    "atlas-terraform-azure-harden",
    "atlas-terraform-gcp-harden"
  ],
  "test_cases": [
    {
      "id": 1,
      "category": "clear_aws_harden",
      "prompt": "I have an Atlas cluster running. How do I add AWS PrivateLink to it using Terraform?",
      "expected_skill": "atlas-terraform-aws-harden",
      "should_not_trigger": "atlas-terraform-getting-started",
      "reasoning": "User has existing cluster and wants AWS PrivateLink — harden skill, not getting-started",
      "trigger_keywords": ["existing cluster", "AWS PrivateLink", "Terraform"]
    },
    {
      "id": 2,
      "category": "clear_aws_harden",
      "prompt": "Add KMS encryption at rest to my Atlas cluster on AWS with Terraform",
      "expected_skill": "atlas-terraform-aws-harden",
      "should_not_trigger": null,
      "reasoning": "KMS/CMEK is a harden-skill trigger on AWS",
      "trigger_keywords": ["KMS", "encryption at rest", "Atlas", "AWS", "Terraform"]
    },
    {
      "id": 3,
      "category": "clear_aws_harden",
      "prompt": "How do I set up backup export to S3 for my Atlas cluster via Terraform?",
      "expected_skill": "atlas-terraform-aws-harden",
      "should_not_trigger": null,
      "reasoning": "S3 backup export is an explicit trigger for the AWS harden skill",
      "trigger_keywords": ["backup export", "S3", "Atlas", "Terraform"]
    },
    {
      "id": 4,
      "category": "clear_aws_harden",
      "prompt": "I want to harden my Atlas cluster with AWS security features using Terraform",
      "expected_skill": "atlas-terraform-aws-harden",
      "should_not_trigger": null,
      "reasoning": "Explicit harden intent with AWS + Atlas + Terraform",
      "trigger_keywords": ["harden", "Atlas", "AWS", "Terraform"]
    },
    {
      "id": 5,
      "category": "clear_azure_harden",
      "prompt": "Add Azure Private Link to my existing Atlas cluster using Terraform",
      "expected_skill": "atlas-terraform-azure-harden",
      "should_not_trigger": "atlas-terraform-aws-harden",
      "reasoning": "Azure Private Link request — triggers azure-harden, not aws-harden",
      "trigger_keywords": ["Azure Private Link", "Atlas", "Terraform"]
    },
    {
      "id": 6,
      "category": "clear_azure_harden",
      "prompt": "Enable Azure Key Vault CMEK encryption for my Atlas cluster via Terraform",
      "expected_skill": "atlas-terraform-azure-harden",
      "should_not_trigger": null,
      "reasoning": "Azure Key Vault CMEK is an explicit trigger for the azure-harden skill",
      "trigger_keywords": ["Azure Key Vault", "CMEK", "Atlas", "Terraform"]
    },
    {
      "id": 7,
      "category": "clear_azure_harden",
      "prompt": "Set up Atlas backup export to Azure Blob Storage with Terraform",
      "expected_skill": "atlas-terraform-azure-harden",
      "should_not_trigger": null,
      "reasoning": "Azure Blob backup export is an explicit trigger for the azure-harden skill",
      "trigger_keywords": ["Azure Blob", "backup export", "Atlas", "Terraform"]
    },
    {
      "id": 8,
      "category": "clear_gcp_harden",
      "prompt": "How do I add GCP Private Service Connect to my Atlas cluster using Terraform?",
      "expected_skill": "atlas-terraform-gcp-harden",
      "should_not_trigger": "atlas-terraform-aws-harden",
      "reasoning": "GCP Private Service Connect is an explicit trigger for the gcp-harden skill",
      "trigger_keywords": ["GCP", "Private Service Connect", "Atlas", "Terraform"]
    },
    {
      "id": 9,
      "category": "clear_gcp_harden",
      "prompt": "Enable Cloud KMS encryption at rest for my Atlas cluster on GCP with Terraform",
      "expected_skill": "atlas-terraform-gcp-harden",
      "should_not_trigger": null,
      "reasoning": "Cloud KMS on GCP is an explicit trigger for gcp-harden",
      "trigger_keywords": ["Cloud KMS", "GCP", "Atlas", "Terraform"]
    },
    {
      "id": 10,
      "category": "clear_gcp_harden",
      "prompt": "Add GCS backup export to my existing Atlas GCP cluster via Terraform",
      "expected_skill": "atlas-terraform-gcp-harden",
      "should_not_trigger": null,
      "reasoning": "GCS backup export is an explicit trigger for gcp-harden",
      "trigger_keywords": ["GCS", "backup export", "Atlas", "GCP", "Terraform"]
    },
    {
      "id": 11,
      "category": "no_trigger_getting_started",
      "prompt": "I want to create a new MongoDB Atlas cluster on AWS using Terraform",
      "expected_skill": "atlas-terraform-getting-started",
      "should_not_trigger": "atlas-terraform-aws-harden",
      "reasoning": "New cluster creation — getting-started skill, not harden",
      "trigger_keywords": ["create", "new", "Atlas cluster", "AWS", "Terraform"]
    },
    {
      "id": 12,
      "category": "no_trigger_getting_started",
      "prompt": "Help me get started with the MongoDB Atlas Terraform provider for Azure",
      "expected_skill": "atlas-terraform-getting-started",
      "should_not_trigger": "atlas-terraform-azure-harden",
      "reasoning": "Getting started intent — not harden",
      "trigger_keywords": ["get started", "Atlas", "Terraform", "Azure"]
    },
    {
      "id": 13,
      "category": "no_trigger_natural_language_querying",
      "prompt": "Write a MongoDB query to find all orders in the last 7 days",
      "expected_skill": "mongodb-natural-language-querying",
      "should_not_trigger": "atlas-terraform-aws-harden",
      "reasoning": "Query generation — no Terraform intent",
      "trigger_keywords": ["query", "find", "MongoDB", "orders"]
    },
    {
      "id": 14,
      "category": "no_trigger_schema_design",
      "prompt": "Should I embed user sessions in the user document or use a separate sessions collection?",
      "expected_skill": "mongodb-schema-design",
      "should_not_trigger": "atlas-terraform-aws-harden",
      "reasoning": "Schema design question — no Terraform intent",
      "trigger_keywords": ["embed", "collection", "schema"]
    },
    {
      "id": 15,
      "category": "no_trigger_search",
      "prompt": "How do I create a full-text Atlas Search index using Terraform?",
      "expected_skill": null,
      "should_not_trigger": "atlas-terraform-aws-harden",
      "reasoning": "Atlas Search index management is out of scope for all harden skills",
      "trigger_keywords": ["Atlas Search", "index", "Terraform"]
    },
    {
      "id": 16,
      "category": "ambiguous_harden_intent",
      "prompt": "How do I secure my Atlas cluster with Terraform?",
      "expected_skill": "atlas-terraform-aws-harden",
      "should_not_trigger": "atlas-terraform-getting-started",
      "reasoning": "Secure/harden intent with Atlas + Terraform — defaults to aws-harden (most common cloud), skill should ask for cloud provider",
      "trigger_keywords": ["secure", "Atlas", "Terraform"]
    },
    {
      "id": 17,
      "category": "post-getting-started-continuation",
      "prompt": "I just deployed my Atlas cluster with Terraform using the getting-started guide. Now I want to add PrivateLink and KMS encryption on AWS.",
      "expected_skill": "atlas-terraform-aws-harden",
      "should_not_trigger": "atlas-terraform-getting-started",
      "reasoning": "User completed getting-started and now wants hardening — triggers aws-harden",
      "trigger_keywords": ["PrivateLink", "KMS", "AWS", "Atlas", "Terraform", "existing"]
    }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add testing/skills-boundaries/atlas-terraform-harden-vs-skills.json
git commit -m "test: add skill boundary tests for atlas-terraform harden skills"
```
