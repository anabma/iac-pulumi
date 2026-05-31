# Vasaloppet Infrastructure – Pulumi on AWS

Examensarbete – Chas Academy DevOps 2025

This project recreates Vasaloppet's cloud infrastructure using [Pulumi](https://www.pulumi.com/) on AWS, as part of a comparison with the original Terraform implementation on IBM Cloud.

> **Note:** The original infrastructure was built with Terraform on IBM Cloud during an internship at Atea. Since Pulumi has no official IBM Cloud provider, this implementation runs on AWS instead. This limitation is itself one of the key findings of the thesis.

---

## What this deploys

| Resource | AWS Service |
|---|---|
| VPC + subnets (public + 2x private) | aws:ec2:Vpc / Subnet |
| Internet Gateway + NAT Gateway | aws:ec2:InternetGateway / NatGateway |
| Route tables | aws:ec2:RouteTable |
| Bastion host | aws:ec2:Instance (t3.micro) |
| Security groups (bastion + db) | aws:ec2:SecurityGroup |
| PostgreSQL 15 database | aws:rds:Instance |
| Object storage (2 buckets) | aws:s3:Bucket |
| Log group | aws:cloudwatch:LogGroup |
| IAM role + policy | aws:iam:Role / RolePolicy |

**Total: 29 resources** in region `eu-north-1` (Stockholm)

> **Not included:** The app module from the Terraform project ran containers from IBM Container Registry (icr.io) with IBM WatsonX integration. Neither ICR nor WatsonX exist on AWS, so the app module has been removed. This is documented in the thesis discussion.

---

## Project structure

```
vasaloppet-pulumi/
├── __main__.py              # Root – equivalent of Terraform's main.tf
├── Pulumi.yaml              # Project metadata – do not edit
├── Pulumi.dev.yaml          # Dev config – auto-updated by pulumi config set
├── requirements.txt
├── Makefile                 # Linux/macOS automation
├── make.ps1                 # Windows automation
├── setup.sh                 # First-time setup script (macOS/Linux)
├── setup.ps1                # First-time setup script (Windows)
├── .env.example             # Copy to .env and fill in your AWS credentials
├── .gitignore
├── .github/
│   └── workflows/
│       └── pulumi.yml       # GitHub Actions CI/CD pipeline
└── modules/
    ├── __init__.py
    ├── network.py           # VPC, subnets, NAT Gateway, route tables
    ├── security.py          # Security groups
    ├── bastion.py           # Bastion EC2 instance
    └── database.py          # RDS PostgreSQL
```

### Comparison with Terraform project structure

| | Terraform (IBM Cloud) | Pulumi (AWS) |
|---|---|---|
| Files | ~20 .tf files | 7 Python files |
| Lines of code | ~850 HCL | ~450 Python |
| Module pattern | 3 files per module | 1 Python class per module |
| CI/CD | Self-hosted GitLab Runner (EC2) | GitHub Actions (no runner needed) |
| State backend | GitLab HTTP backend | S3 bucket |

---

## Prerequisites

- Python 3.11+
- AWS CLI configured (`aws configure`)
- Pulumi CLI (`pip install pulumi pulumi-aws pulumi-random`)
- An AWS account with credentials

---

## Quick start

### 1. Create your `.env` file

Copy `.env.example` to `.env` and fill in your AWS credentials:

```
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=eu-north-1
```

### 2. Run the setup script

**macOS/Linux:**
```bash
bash setup.sh
```

**Windows:**
```powershell
.\setup.ps1
```

The script will:
- Verify your AWS credentials
- Create an S3 bucket for Pulumi state
- Log in to Pulumi using S3 as backend (no Pulumi Cloud account needed)
- Create the `dev` stack
- Generate an SSH key if you don't have one
- Set all required config values

### 3. Preview and deploy

```bash
# Load credentials
set -a && source .env && set +a
export PULUMI_CONFIG_PASSPHRASE=""

# Preview what will be created (= terraform plan)
pulumi preview --stack dev

# Deploy (= terraform apply)
pulumi up --stack dev
```

### 4. Tear down when done

```bash
pulumi destroy --stack dev --yes
```

> ⚠️ NAT Gateway and RDS cost ~3–4 USD/day. Always destroy when not in use.

---

## State backend

This project uses **AWS S3** as the Pulumi state backend instead of Pulumi Cloud. No extra account needed – just AWS.

```bash
# Create bucket (done once by setup.sh)
aws s3 mb s3://vasaloppet-pulumi-state --region eu-north-1

# Login
pulumi login s3://vasaloppet-pulumi-state
```

---

## GitHub Actions CI/CD

The pipeline in `.github/workflows/pulumi.yml` replaces the self-hosted GitLab Runner from the Terraform project. GitHub Actions runs on GitHub's own servers – no runner EC2 instance needed.

| Event | Action |
|---|---|
| Pull request | `pulumi preview` – comments result on PR |
| Push to main | `pulumi up` – deploys to AWS |

Set these secrets in your GitHub repo (Settings → Secrets → Actions):

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `PULUMI_CONFIG_PASSPHRASE` | Leave empty or set any value |

---

## Useful commands

```bash
pulumi preview --stack dev          # Show what will change
pulumi up --stack dev               # Deploy
pulumi destroy --stack dev --yes    # Tear down everything
pulumi stack output --stack dev     # Show outputs (IP addresses etc.)
pulumi config --stack dev           # Show all config values

make ssh-bastion                    # SSH to bastion host
make db-tunnel                      # Open database tunnel (terminal 1)
make db-connect                     # Connect to database (terminal 2)
```

---

## Known differences from Terraform/IBM Cloud

| Aspect | Terraform (IBM Cloud) | Pulumi (AWS) |
|---|---|---|
| IBM Cloud provider | ✓ Official | ✗ Does not exist |
| App module | ✓ ICR containers + WatsonX | ✗ Removed – IBM-specific |
| NAT Gateway | Automatic via public gateway | Explicit NatGateway resource |
| DB endpoint | Via VPC Endpoint Gateway | RDS in private subnet directly |
| Username reserved | `admin` works | `admin` reserved – use `dbadmin` |

---

## Thesis

This project is part of an examensarbete (bachelor thesis) at Chas Academy, DevOps programme 2025.

**Title:** Infrastructure as Code – En jämförelse mellan Terraform och Pulumi för Vasaloppets molninfrastruktur

**Conclusion:** Terraform is the better choice for this specific project, primarily because Pulumi lacks an IBM Cloud provider, and secondarily because Vasaloppet's app is tightly coupled to IBM WatsonX and IBM Container Registry.

For teams running on AWS/Azure/GCP with Python experience, Pulumi is a genuine alternative – fewer files, more expressive code and a clean stack-based environment management system.