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
1. `Bash`: `gh api repos/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-aws/releases/latest --jq '.tag_name'`
2. `WebSearch` (fallback if gh fails): query `terraform-mongodbatlas-modules/atlas-aws/mongodbatlas terraform registry latest version`

Constraint: `~> 0.3`. Public Preview module.

### 1c: AWS provider

Requires `>= 6.0`. Use constraint `~> 6.0`. No version resolution needed.

### 1d: Inspect atlas-aws module interface

Fetch the module's actual variable definitions from GitHub before generating any HCL:

```bash
gh api repos/terraform-mongodbatlas-modules/terraform-mongodbatlas-atlas-aws/contents/variables.tf --jq '.content' | base64 -d
```

Read the output and record every declared variable name. In Step 3 (File 3: main.tf), pass **only** arguments whose names appear in this file. Do not use any argument name absent from the fetched `variables.tf`. If the command fails, proceed with the template in Step 3 but flag to the user that the module interface could not be verified and they should check the [module inputs](https://registry.terraform.io/modules/terraform-mongodbatlas-modules/atlas-aws/mongodbatlas/latest?tab=inputs) manually.

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
- Store as `USER_VPC_CIDR` and `USER_AZ_LIST`. Set `NETWORKING = create`.

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

For `terraform.tfvars.example`, activate only the networking block matching the user's Q4 choice and delete the other networking block. Do the same for the KMS and S3 blocks — keep only the block that matches the user's Q5 and Q6 choices and delete the other.

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
}

variable "availability_zones" {
  description = "AWS availability zones for subnets."
  type        = list(string)
}
```

Apply the same KMS and S3 conditional appends as File 2a.

---

### File 3: `main.tf`

⚠️ **Use the interface from Step 1d.** Generate the `module "atlas_aws"` block using **only** argument names that appeared in the fetched `variables.tf`. The template below shows the expected structure — verify every argument name against the fetched interface and omit any that are not declared there. Do not assume argument names: if `cluster_name` or `region` are absent from the fetched variables, do not include them.

Build from the template below. Apply the combination rules after the code block.

```hcl
provider "mongodbatlas" {
  client_id     = var.atlas_client_id
  client_secret = var.atlas_client_secret
}

provider "aws" {
  region = var.aws_region
}

# --- NETWORKING = create only: include aws_vpc + aws_subnet resources ---
resource "aws_vpc" "atlas" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "atlas-harden-vpc" }
}

resource "aws_subnet" "atlas" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.atlas.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]
  tags = { Name = "atlas-harden-subnet-${count.index}" }
}
# --- end NETWORKING = create block ---

module "atlas_aws" {
  source  = "terraform-mongodbatlas-modules/atlas-aws/mongodbatlas"
  version = "~> 0.3"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.atlas_region

  privatelink_endpoints = [
    {
      region     = var.atlas_region
      subnet_ids = SUBNET_IDS_PLACEHOLDER
    }
  ]

  # Creates an IAM role for Atlas Cloud Provider Access (KMS + S3 permissions) with module defaults.
  cloud_provider_access = {}

  encryption  = KMS_PLACEHOLDER
  backup_export = S3_PLACEHOLDER
}
```

⚠️ **Combination rules:** Replace each placeholder based on user answers.

| Choice | Placeholder | Substitute with |
|---|---|---|
| NETWORKING = byo | `SUBNET_IDS_PLACEHOLDER` | `var.subnet_ids` |
| NETWORKING = create | `SUBNET_IDS_PLACEHOLDER` | `aws_subnet.atlas[*].id` |
| NETWORKING = create | aws_vpc + aws_subnet blocks | **keep** |
| NETWORKING = byo | aws_vpc + aws_subnet blocks | **remove** |
| KMS = byo | `KMS_PLACEHOLDER` | `{ enabled = true, kms_key_arn = var.kms_key_arn }` |
| KMS = create | `KMS_PLACEHOLDER` | `{ enabled = true, create_kms_key = { enabled = true } }` |
| S3 = byo | `S3_PLACEHOLDER` | `{ enabled = true, bucket_name = var.s3_bucket_name }` |
| S3 = create | `S3_PLACEHOLDER` | `{ enabled = true, create_s3_bucket = { enabled = true } }` |

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
# availability_zones = ["us-east-1a", "us-east-1b"]

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

5. If output **contains** `Success! The configuration is valid.` → present files to user and proceed to Step 5.
   If validation fails → read the error, fix the affected file, and re-validate. If the same error persists after two fix attempts, present the files with a note that HCL validation could not be completed.

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
