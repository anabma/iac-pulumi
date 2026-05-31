#!/bin/bash
# ============================================================
# Vasaloppet Pulumi – Local Setup Script
# Run once to configure everything on your machine.
# Usage: bash setup.sh
# ============================================================

set -e

echo ""
echo "======================================"
echo "  Vasaloppet Pulumi Setup"
echo "======================================"
echo ""

# ── LOAD .env ────────────────────────────────────────────────
if [ ! -f .env ]; then
  echo ".env file not found!"
  echo ""
  echo "Create a file called .env in this folder with:"
  echo ""
  echo "  AWS_ACCESS_KEY_ID=your-access-key"
  echo "  AWS_SECRET_ACCESS_KEY=your-secret-key"
  echo "  AWS_REGION=eu-north-1"
  echo ""
  exit 1
fi

set -a && source .env && set +a
echo ".env loaded"

# ── CHECK AWS ────────────────────────────────────────────────
echo ""
echo "Checking AWS credentials..."
aws sts get-caller-identity --query Account --output text > /dev/null 2>&1 \
  && echo "AWS credentials OK" \
  || { echo "AWS credentials failed. Check your .env file."; exit 1; }

# ── PASSPHRASE ───────────────────────────────────────────────
export PULUMI_CONFIG_PASSPHRASE=""
echo "Passphrase set to empty"

# ── S3 BUCKET ────────────────────────────────────────────────
echo ""
echo "Creating S3 bucket for state..."
aws s3 mb s3://vasaloppet-pulumi-state --region eu-north-1 2>/dev/null \
  && echo "S3 bucket created" \
  || echo "S3 bucket already exists (that's fine)"

# ── PULUMI LOGIN ─────────────────────────────────────────────
echo ""
echo "Logging in to S3 backend..."
pulumi login s3://vasaloppet-pulumi-state
echo "Logged in to S3"

# ── STACK ────────────────────────────────────────────────────
echo ""
echo "Creating dev stack..."
pulumi stack init dev 2>/dev/null \
  && echo "Stack 'dev' created" \
  || { pulumi stack select dev && echo "Stack 'dev' already exists, selected"; }

# ── SSH KEY ──────────────────────────────────────────────────
echo ""
if [ ! -f ~/.ssh/id_rsa ]; then
  echo "Creating SSH key..."
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "vasaloppet"
  echo "SSH key created"
else
  echo "SSH key already exists"
fi

# ── PULUMI CONFIG ─────────────────────────────────────────────
echo ""
echo "Setting Pulumi config..."

pulumi config set aws:region eu-north-1 --stack dev
echo "aws:region = eu-north-1"

pulumi config set vasaloppet-infrastructure:ssh_public_key "$(cat ~/.ssh/id_rsa.pub)" --stack dev
echo "ssh_public_key set"

echo ""
read -sp "Choose a database password (min 8 characters, e.g. Pulumi123): " DB_PASS
echo ""
pulumi config set --secret vasaloppet-infrastructure:db_password "$DB_PASS" --stack dev
echo "db_password set"

pulumi config set vasaloppet-infrastructure:image_reference "nginx:latest" --stack dev
pulumi config set vasaloppet-infrastructure:dashboard_image_reference "nginx:latest" --stack dev
echo "image references set"

# ── DONE ─────────────────────────────────────────────────────
echo ""
echo "======================================"
echo "Setup complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  pulumi preview --stack dev   <- check what will be created"
echo "  pulumi up --stack dev        <- deploy infrastructure"
echo ""
echo "When done for the day:"
echo "  pulumi destroy --stack dev --yes"
echo ""