# Client Infrastructure – Pulumi / AWS
# Run from the client-pulumi/ directory.
# CI/CD is handled by GitHub Actions – no runner instance needed.

.PHONY: help bootstrap install-tools setup-ssh login-aws init preview deploy
.PHONY: ssh-bastion ssh-app db-tunnel db-connect app-tunnel output status clean destroy

.DEFAULT_GOAL := help

help:
	@echo ""
	@echo "Commands:"
	@echo "  make bootstrap    - First time setup – install everything and deploy"
	@echo "  make preview      - Show what will be created (= terraform plan)"
	@echo "  make deploy       - Deploy infrastructure (= terraform apply)"
	@echo "  make ssh-bastion  - SSH to bastion host"
	@echo "  make ssh-app      - SSH to app server"
	@echo "  make db-tunnel    - Open database tunnel (terminal 1)"
	@echo "  make db-connect   - Connect to database (terminal 2)"
	@echo "  make app-tunnel   - Forward API :8000 and Dashboard :8501 locally"
	@echo "  make output       - Show outputs (IP addresses etc.)"
	@echo "  make status       - Show current status"
	@echo "  make clean        - Clear cache"
	@echo "  make destroy      - Take down all infrastructure"
	@echo ""
	@echo "Note: CI/CD runs automatically via GitHub Actions – no runner needed."
	@echo ""

bootstrap: install-tools setup-ssh login-aws init deploy
	@echo "Setup complete!"

install-tools:
	@echo "Installing tools..."
	@if command -v brew >/dev/null 2>&1; then \
		command -v python3 >/dev/null || brew install python3; \
		command -v aws >/dev/null || brew install awscli; \
	elif command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update -qq; \
		sudo apt-get install -y python3 python3-pip awscli; \
	fi
	@pip3 install pulumi pulumi-aws pulumi-random --quiet
	@command -v pulumi >/dev/null && echo "pulumi ok" || echo "pulumi missing"
	@command -v aws >/dev/null && echo "aws ok" || echo "aws missing"

setup-ssh:
	@if [ ! -f ~/.ssh/id_rsa ]; then \
		ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "client"; \
		chmod 600 ~/.ssh/id_rsa; \
		echo "SSH key created"; \
	else \
		echo "SSH key already exists"; \
	fi
	@pulumi config set client-infrastructure:ssh_public_key "$$(cat ~/.ssh/id_rsa.pub)" --stack dev
	@echo "SSH key set in Pulumi config"

login-aws:
	@if [ -z "$$AWS_ACCESS_KEY_ID" ]; then \
		echo "AWS_ACCESS_KEY_ID not set – run: set -a && source .env && set +a"; \
		exit 1; \
	fi
	@aws configure set aws_access_key_id $$AWS_ACCESS_KEY_ID
	@aws configure set aws_secret_access_key $$AWS_SECRET_ACCESS_KEY
	@aws configure set region $${AWS_REGION:-eu-north-1}
	@aws sts get-caller-identity --query Account --output text && echo "AWS login OK"

init:
	@pip3 install -r requirements.txt --quiet
	@if ! pulumi stack ls 2>/dev/null | grep -q "dev"; then \
		pulumi stack init dev; \
		echo "Stack 'dev' created"; \
	else \
		pulumi stack select dev; \
		echo "Stack 'dev' selected"; \
	fi

preview:
	@pulumi preview --stack dev

deploy:
	@pulumi up --stack dev

ssh-bastion:
	@BASTION_IP=$$(pulumi stack output bastion_public_ip --stack dev); \
	ssh -i ~/.ssh/id_rsa ec2-user@$$BASTION_IP

ssh-app:
	@eval "$$(ssh-agent -s)" && \
	ssh-add ~/.ssh/id_rsa && \
	BASTION_IP=$$(pulumi stack output bastion_public_ip --stack dev) && \
	APP_IP=$$(pulumi stack output app_private_ip --stack dev 2>/dev/null || echo "not deployed") && \
	ssh -i ~/.ssh/id_rsa -A -o StrictHostKeyChecking=no -J ec2-user@$$BASTION_IP ec2-user@$$APP_IP

db-tunnel:
	@echo "Opening database tunnel..."
	@echo "Keep this window open."
	@echo "Open a new terminal and run: make db-connect"
	@BASTION_IP=$$(pulumi stack output bastion_public_ip --stack dev); \
	DB_HOST=$$(pulumi stack output db_address --stack dev); \
	DB_PORT=$$(pulumi stack output db_port --stack dev); \
	ssh -i ~/.ssh/id_rsa -N -L 5433:$$DB_HOST:$$DB_PORT ec2-user@$$BASTION_IP

db-connect:
	@DB_NAME=$$(pulumi stack output db_name --stack dev); \
	DB_USER=$$(pulumi stack output db_user --stack dev); \
	PGPASSWORD=$$(pulumi config get client-infrastructure:db_password --stack dev) \
	psql -h localhost -p 5433 -U $$DB_USER -d $$DB_NAME

app-tunnel:
	@echo "  API:       http://localhost:8000/docs"
	@echo "  Dashboard: http://localhost:8501"
	@echo "Keep this window open."
	@eval "$$(ssh-agent -s)" && \
	ssh-add ~/.ssh/id_rsa && \
	BASTION_IP=$$(pulumi stack output bastion_public_ip --stack dev) && \
	APP_IP=$$(pulumi stack output app_private_ip --stack dev) && \
	ssh -i ~/.ssh/id_rsa -N \
		-o StrictHostKeyChecking=no \
		-L 8000:localhost:8000 \
		-L 8501:localhost:8501 \
		-J ec2-user@$$BASTION_IP \
		ec2-user@$$APP_IP

output:
	@pulumi stack output --stack dev

status:
	@echo "Status"
	@echo "Bastion: $$(pulumi stack output bastion_public_ip --stack dev 2>/dev/null || echo 'not deployed')"
	@echo "DB:      $$(pulumi stack output db_address --stack dev 2>/dev/null || echo 'not deployed')"

clean:
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@echo "Cache cleared"

destroy:
	@echo "This will destroy ALL infrastructure!"
	@read -p "Type 'delete everything' to continue: " confirm; \
	if [ "$$confirm" = "delete everything" ]; then \
		pulumi destroy --stack dev --yes; \
		echo "Infrastructure destroyed"; \
	else \
		echo "Cancelled"; \
	fi
