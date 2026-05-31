# ============================================================
# Vasaloppet Pulumi – Local Setup Script (Windows)
# Run once to configure everything on your machine.
# Usage: .\setup.ps1
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================"
Write-Host "  Vasaloppet Pulumi Setup"
Write-Host "======================================"
Write-Host ""

# ── LOAD .env ────────────────────────────────────────────────
if (-not (Test-Path ".env")) {
    Write-Host ".env file not found!"
    Write-Host ""
    Write-Host "Create a file called .env in this folder with:"
    Write-Host ""
    Write-Host "  AWS_ACCESS_KEY_ID=your-access-key"
    Write-Host "  AWS_SECRET_ACCESS_KEY=your-secret-key"
    Write-Host "  AWS_REGION=eu-north-1"
    Write-Host ""
    exit 1
}

Get-Content ".env" | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
}
Write-Host ".env loaded"

# ── CHECK AWS ────────────────────────────────────────────────
Write-Host ""
Write-Host "Checking AWS credentials..."
try {
    aws sts get-caller-identity --query Account --output text | Out-Null
    Write-Host "AWS credentials OK"
} catch {
    Write-Host "AWS credentials failed. Check your .env file."
    exit 1
}

# ── PASSPHRASE ───────────────────────────────────────────────
$env:PULUMI_CONFIG_PASSPHRASE = ""
Write-Host "Passphrase set to empty"

# ── S3 BUCKET ────────────────────────────────────────────────
Write-Host ""
Write-Host "Creating S3 bucket for state..."
try {
    aws s3 mb s3://vasaloppet-pulumi-state --region eu-north-1 2>$null
    Write-Host "S3 bucket created"
} catch {
    Write-Host "S3 bucket already exists (that's fine)"
}

# ── PULUMI LOGIN ─────────────────────────────────────────────
Write-Host ""
Write-Host "Logging in to S3 backend..."
pulumi login s3://vasaloppet-pulumi-state
Write-Host "Logged in to S3"

# ── STACK ────────────────────────────────────────────────────
Write-Host ""
Write-Host "Creating dev stack..."
try {
    pulumi stack init dev 2>$null
    Write-Host "Stack 'dev' created"
} catch {
    pulumi stack select dev
    Write-Host "Stack 'dev' already exists, selected"
}

# ── SSH KEY ──────────────────────────────────────────────────
Write-Host ""
$keyPath = "$HOME\.ssh\id_rsa"
if (-not (Test-Path $keyPath)) {
    Write-Host "Creating SSH key..."
    ssh-keygen -t rsa -b 4096 -f $keyPath -N '""' -C "vasaloppet"
    Write-Host "SSH key created"
} else {
    Write-Host "SSH key already exists"
}

# ── PULUMI CONFIG ─────────────────────────────────────────────
Write-Host ""
Write-Host "Setting Pulumi config..."

pulumi config set aws:region eu-north-1 --stack dev
Write-Host "aws:region = eu-north-1"

$pubKey = Get-Content "$keyPath.pub" -Raw
pulumi config set vasaloppet-infrastructure:ssh_public_key $pubKey --stack dev
Write-Host "ssh_public_key set"

Write-Host ""
$DB_PASS = Read-Host -AsSecureString "Choose a database password (min 8 characters, e.g. Pulumi123)"
$DB_PASS_PLAIN = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($DB_PASS))
pulumi config set --secret vasaloppet-infrastructure:db_password $DB_PASS_PLAIN --stack dev
Write-Host "db_password set"

pulumi config set vasaloppet-infrastructure:image_reference "nginx:latest" --stack dev
pulumi config set vasaloppet-infrastructure:dashboard_image_reference "nginx:latest" --stack dev
Write-Host "image references set"

# ── DONE ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "======================================"
Write-Host "Setup complete!"
Write-Host "======================================"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  pulumi preview --stack dev   <- check what will be created"
Write-Host "  pulumi up --stack dev        <- deploy infrastructure"
Write-Host ""
Write-Host "When done for the day:"
Write-Host "  pulumi destroy --stack dev --yes"
Write-Host ""