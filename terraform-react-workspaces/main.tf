terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # No backend block for local state
}

provider "aws" {
  region = local.config.region
}

locals {
  env = terraform.workspace
  env_configs = {
    dev = {
      name_suffix = "dev"
      region      = "ap-south-1"
      tags        = { Environment = "dev" }
    }
    prod = {
      name_suffix = "prod"
      region      = "ap-south-1"
      tags        = { Environment = "prod" }
    }
  }
  config = local.env_configs[local.env]
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "react-app-${local.config.name_suffix}-${random_string.suffix.result}"
#  tags   = local.config.tags
  tags = merge(local.config.tags, local.env == "dev" ? { DevOnly = "true" } : {})
}

resource "aws_s3_bucket_website_configuration" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "app_bucket" {
  depends_on = [aws_s3_bucket_public_access_block.app_bucket]
  bucket     = aws_s3_bucket.app_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.app_bucket.arn}/*"
      },
    ]
  })
}

output "bucket_name" {
  value = aws_s3_bucket.app_bucket.bucket
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.app_bucket.website_endpoint
}