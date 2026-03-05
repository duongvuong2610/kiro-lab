# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = var.config.bucket_name

  tags = {
    Name        = "${var.config.environment}-storage"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.config.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "transition-to-ia-and-glacier"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = var.config.lifecycle_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.config.lifecycle_glacier_days
      storage_class = "GLACIER"
    }
  }
}
