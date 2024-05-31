module "aws_config_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["aws-config"]
  context    = module.this.context
}

module "storage" {
  source  = "cloudposse/s3-log-storage/aws"
  version = "1.4.3"
  count   = module.this.enabled ? 1 : 0

  acl                                    = "private"
  lifecycle_prefix                       = var.lifecycle_prefix
  lifecycle_tags                         = var.lifecycle_tags
  force_destroy                          = var.force_destroy
  lifecycle_rule_enabled                 = var.lifecycle_rule_enabled
  versioning_enabled                     = true
  noncurrent_version_expiration_days     = var.noncurrent_version_expiration_days
  noncurrent_version_transition_days     = var.noncurrent_version_transition_days
  standard_transition_days               = var.standard_transition_days
  glacier_transition_days                = var.glacier_transition_days
  enable_glacier_transition              = var.enable_glacier_transition
  expiration_days                        = var.expiration_days
  abort_incomplete_multipart_upload_days = var.abort_incomplete_multipart_upload_days
  sse_algorithm                          = var.sse_algorithm
  kms_master_key_arn                     = var.kms_master_key_arn
  block_public_acls                      = true
  block_public_policy                    = true
  ignore_public_acls                     = true
  restrict_public_buckets                = true
  access_log_bucket_name                 = var.access_log_bucket_name
  allow_ssl_requests_only                = var.allow_ssl_requests_only
  source_policy_documents                = [join("", data.aws_iam_policy_document.aws_config_bucket_policy[*].json)]

  bucket_notifications_enabled = var.bucket_notifications_enabled
  bucket_notifications_type    = var.bucket_notifications_type
  bucket_notifications_prefix  = var.bucket_notifications_prefix

  tags       = module.this.tags
  attributes = ["aws-config"]
  context    = module.this.context
}

data "aws_iam_policy_document" "aws_config_bucket_policy" {
  count = module.this.enabled ? 1 : 0

  statement {
    sid = "AWSConfigBucketPermissionsCheck"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    resources = [
      local.s3_bucket_arn
    ]
  }

  statement {
    sid = "AWSConfigBucketExistenceCheck"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    effect  = "Allow"
    actions = ["s3:ListBucket"]

    resources = [
      local.s3_bucket_arn
    ]
  }

  statement {
    sid = "AWSConfigBucketDelivery"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    effect  = "Allow"
    actions = ["s3:PutObject"]

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
data "aws_partition" "current" {}

locals {
  current_account_id = data.aws_caller_identity.current.account_id
  config_spn         = "config.amazonaws.com"
  s3_bucket_arn      = format("arn:%s:s3:::%s", data.aws_partition.current.id, module.aws_config_label.id)
  s3_object_prefix   = format("%s/AWSLogs/*", local.s3_bucket_arn)
}

