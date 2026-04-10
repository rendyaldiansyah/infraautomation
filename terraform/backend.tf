# ── Terraform settings & remote state ──────────────────────
# JANGAN tambahkan provider block di sini.
# Semua provider dikonfigurasi di main.tf
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Supplied at terraform init:
    #   terraform init \
    #     -backend-config="bucket=lks-tfstate-yourname-2026" \
    #     -backend-config="key=prod/terraform.tfstate" \
    #     -backend-config="region=us-east-1"
  }
}
