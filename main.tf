module "aws_config_label" {
  source  = "cloudposse/label/null"
  version = "0.21.0"

  attributes = ["aws-config"]
  context    = module.this.context
}
resource "aws_s3_bucket" "default" {
  count         = module.this.enabled ? 1 : 0
  bucket        = module.aws_config_label.id
  force_destroy = var.force_destroy

  #---------------------------------------------------------------------------------------------------------------------
  # A config item shouldn't be ever be overwritten, but if it by chance is, enable versioning so we don't lose data 
  #---------------------------------------------------------------------------------------------------------------------
  versioning {
    enabled = true
  }

  lifecycle_rule {
    id                                     = module.aws_config_label.id
    enabled                                = var.lifecycle_rule_enabled
    prefix                                 = var.lifecycle_prefix
    tags                                   = var.lifecycle_tags
    abort_incomplete_multipart_upload_days = var.abort_incomplete_multipart_upload_days

    noncurrent_version_expiration {
      days = var.noncurrent_version_expiration_days
    }

    dynamic "noncurrent_version_transition" {
      for_each = var.enable_glacier_transition ? [1] : []

      content {
        days          = var.noncurrent_version_transition_days
        storage_class = "GLACIER"
      }
    }

    transition {
      days          = var.standard_transition_days
      storage_class = "STANDARD_IA"
    }

    dynamic "transition" {
      for_each = var.enable_glacier_transition ? [1] : []

      content {
        days          = var.glacier_transition_days
        storage_class = "GLACIER"
      }
    }

    expiration {
      days = var.expiration_days
    }

  }

  dynamic "logging" {
    for_each = var.access_log_bucket_name != "" ? [1] : []
    content {
      target_bucket = var.access_log_bucket_name
      target_prefix = "logs/${module.this.id}/"
    }
  }

  # https://docs.aws.amazon.com/AmazonS3/latest/dev/bucket-encryption.html
  # https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#enable-default-server-side-encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = var.sse_algorithm
        kms_master_key_id = var.kms_master_key_arn
      }
    }
  }

  tags = module.this.tags
}

# Refer to the terraform documentation on s3_bucket_public_access_block at
# https://www.terraform.io/docs/providers/aws/r/s3_bucket_public_access_block.html
# for the nuances of the blocking options
resource "aws_s3_bucket_public_access_block" "default" {
  count  = module.this.enabled ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "aws_config_bucket_policy" {
  count = module.this.enabled ? 1 : 0

  statement {
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    effect = "Allow"

    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.default[0].arn
    ]
  }

  statement {
    actions = ["s3:PutObject"]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    resources = [local.s3_object_prefix]
  }
}

#-----------------------------------------------------------------------------------------------------------------------
# Locals and Data Sources
#-----------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

locals {
  current_account_id = data.aws_caller_identity.current.account_id
  s3_bucket_arn      = module.this.enabled ? aws_s3_bucket.default[0].arn : ""
  s3_object_prefix   = format("%s/AWSLogs/%s/Config/*", local.s3_bucket_arn, local.current_account_id)
}
