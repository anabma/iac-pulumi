param([string]$Command = "help")
$ErrorActionPreference = "Stop"

function Load-Env {
    $envFile = Join-Path $PSScriptRoot ".env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^([^#=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
            }
        }
    }
}

function Help {
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  .\make.ps1 bootstrap    - First time setup"
    Write-Host "  .\make.ps1 preview      - Show what will be created"
    Write-Host "  .\make.ps1 deploy       - Deploy infrastructure"
    Write-Host "  .\make.ps1 ssh-bastion  - SSH to bastion host"
    Write-Host "  .\make.ps1 db-tunnel    - Open database tunnel (terminal 1)"
    Write-Host "  .\make.ps1 db-connect   - Connect to database (terminal 2)"
    Write-Host "  .\make.ps1 output       - Show outputs"
    Write-Host "  .\make.ps1 status       - Show status"
    Write-Host "  .\make.ps1 clean        - Clear cache"
    Write-Host "  .\make.ps1 destroy      - Destroy all infrastructure"
    Write-Host ""
    Write-Host "Note: CI/CD runs automatically via GitHub Actions."
    Write-Host ""
}

function Install-Tools {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { Write-Error "Install Chocolatey first"; exit 1 }
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) { choco install python -y }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { choco install awscli -y }
    python -m pip install pulumi pulumi-aws pulumi-random --quiet
    Write-Host "Tools installed"
}

function Setup-SSH {
    $key = "$HOME\.ssh\id_rsa"
    if (-not (Test-Path $key)) {
        ssh-keygen -t rsa -b 4096 -f $key -N '""' -C "vasaloppet"
        Write-Host "SSH key created"
    } else { Write-Host "SSH key already exists" }
    $pubKey = Get-Content "$key.pub" -Raw
    pulumi config set vasaloppet-infrastructure:ssh_public_key $pubKey --stack dev
    Write-Host "SSH key set in Pulumi config"
}

function Login-AWS {
    Load-Env
    if (-not $env:AWS_ACCESS_KEY_ID) { Write-Error "AWS_ACCESS_KEY_ID not set in .env"; exit 1 }
    aws configure set aws_access_key_id $env:AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $env:AWS_SECRET_ACCESS_KEY
    aws configure set region $(if ($env:AWS_REGION) { $env:AWS_REGION } else { "eu-north-1" })
    $account = aws sts get-caller-identity --query Account --output text
    Write-Host "AWS login OK (Account: $account)"
}

function Init {
    python -m pip install -r requirements.txt --quiet
    $stacks = pulumi stack ls 2>$null
    if ($stacks -notmatch "dev") { pulumi stack init dev; Write-Host "Stack 'dev' created" }
    else { pulumi stack select dev; Write-Host "Stack 'dev' selected" }
}

function Preview { pulumi preview --stack dev }
function Deploy  { pulumi up --stack dev }

function SSH-Bastion {
    $ip = pulumi stack output bastion_public_ip --stack dev
    ssh -i "$HOME\.ssh\id_rsa" ec2-user@$ip
}

function DB-Tunnel {
    $bastion = pulumi stack output bastion_public_ip --stack dev
    $dbHost  = pulumi stack output db_address --stack dev
    $dbPort  = pulumi stack output db_port --stack dev
    Write-Host "Keep this window open."
    Write-Host "Open a new terminal and run: .\make.ps1 db-connect"
    ssh -i "$HOME\.ssh\id_rsa" -N -L "5433:$dbHost`:$dbPort" ec2-user@$bastion
}

function DB-Connect {
    $dbName = pulumi stack output db_name --stack dev
    $dbUser = pulumi stack output db_user --stack dev
    $env:PGPASSWORD = pulumi config get vasaloppet-infrastructure:db_password --stack dev
    $env:Path += ";C:\Program Files\PostgreSQL\18\bin"
    psql -h localhost -p 5433 -U $dbUser -d $dbName
}

function Output  { pulumi stack output --stack dev }

function Status {
    Write-Host "Status"
    $bastion = pulumi stack output bastion_public_ip --stack dev 2>$null
    $db      = pulumi stack output db_address --stack dev 2>$null
    Write-Host "Bastion: $(if ($bastion) { $bastion } else { 'not deployed' })"
    Write-Host "DB:      $(if ($db) { $db } else { 'not deployed' })"
}

function Clean {
    Get-ChildItem -Recurse -Filter "__pycache__" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cache cleared"
}

function Destroy {
    $confirm = Read-Host "Type 'delete everything' to destroy all infrastructure"
    if ($confirm -eq "delete everything") { pulumi destroy --stack dev --yes; Write-Host "Infrastructure destroyed" }
    else { Write-Host "Cancelled" }
}

function Bootstrap { Install-Tools; Setup-SSH; Login-AWS; Init; Deploy }

switch ($Command.ToLower()) {
    "help"          { Help }
    "bootstrap"     { Bootstrap }
    "install-tools" { Install-Tools }
    "login-aws"     { Login-AWS }
    "init"          { Init }
    "preview"       { Preview }
    "deploy"        { Deploy }
    "ssh-bastion"   { SSH-Bastion }
    "db-tunnel"     { DB-Tunnel }
    "db-connect"    { DB-Connect }
    "output"        { Output }
    "status"        { Status }
    "clean"         { Clean }
    "destroy"       { Destroy }
    default         { Help }
}