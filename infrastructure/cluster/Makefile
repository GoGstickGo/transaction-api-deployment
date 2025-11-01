.PHONY: help init plan apply destroy validate format clean get-credentials ouput

# Default target
help:
	@echo "GKE Cluster Terraform Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make init            - Initialize Terraform"
	@echo "  make validate        - Validate Terraform configuration"
	@echo "  make format          - Format Terraform files"
	@echo "  make plan            - Run Terraform plan"
	@echo "  make apply           - Apply Terraform configuration"
	@echo "  make destroy         - Destroy all resources"
	@echo "  make get-credentials - Configure kubectl with cluster credentials"
	@echo "  make clean           - Clean Terraform cache and state backups"
	@echo "  make output          - Show Terraform outputs"
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

# Get cluster credentials for kubectl
get-credentials:
	@echo "Fetching cluster credentials..."
	gcloud container clusters get-credentials transaction-api-assesment  --zone europe-west1 --project transaction-api-2446


# Clean Terraform cache and backups
clean:
	@echo "Cleaning Terraform cache and backups..."
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate.backup
	rm -f *.tfplan
	@echo "Clean complete. Run 'make init' before using Terraform again."

# Show Terraform outputs
output:
	@echo "Terraform Outputs:"
	@terraform output

# Refresh Terraform state
refresh:
	@echo "Refreshing Terraform state..."
	terraform refresh

# Show Terraform state
show:
	@echo "Terraform State:"
	@terraform show