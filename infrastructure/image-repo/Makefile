.PHONY: help init plan apply destroy validate format clean

# Default target
help:
	@echo "GKE Docker image repository Terraform Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make init            - Initialize Terraform"
	@echo "  make validate        - Validate Terraform configuration"
	@echo "  make format          - Format Terraform files"
	@echo "  make plan            - Run Terraform plan"
	@echo "  make apply           - Apply Terraform configuration"
	@echo "  make destroy         - Destroy all resources"
	@echo "  make clean           - Clean Terraform cache and state backups"
	@echo ""

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	terraform init

# Validate configuration
validate:
	@echo "Validating Terraform configuration..."
	terraform validate

# Format Terraform files
format:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive

# Plan changes
plan:
	@echo "Running Terraform plan..."
	terraform plan

# Apply changes
apply:
	@echo "Applying Terraform configuration..."
	terraform apply

# Apply with auto-approve (use with caution)
apply-auto:
	@echo "Applying Terraform configuration (auto-approved)..."
	terraform apply -auto-approve

# Destroy resources
destroy:
	@echo "Destroying Terraform resources..."
	terraform destroy

# Destroy with auto-approve (use with caution)
destroy-auto:
	@echo "Destroying Terraform resources (auto-approved)..."
	terraform destroy -auto-approve

# Clean Terraform cache and backups
clean:
	@echo "Cleaning Terraform cache and backups..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate.backup
	rm -f *.tfplan
	@echo "Clean complete. Run 'make init' before using Terraform again."

# Refresh Terraform state
refresh:
	@echo "Refreshing Terraform state..."
	terraform refresh

# Show Terraform state
show:
	@echo "Terraform State:"
	@terraform show