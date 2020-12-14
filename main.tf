module "aws_config_label" {
  source  = "cloudposse/label/null"
  version = "0.21.0"

  attributes = ["aws-config"]
  context    = module.this.context
}

module "storage" {
  source  = "cloudposse/s3-log-storage/aws"
  version = "0.14.0"
  count   = module.this.enabled ? 1 : 0

  policy                                 = data.aws_iam_policy_document.aws_config_bucket_policy[0].json
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

  tags       = module.this.tags
  attributes = ["aws-config"]
  context    = module.this.context
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
      local.s3_bucket_arn
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
  s3_bucket_arn      = module.this.enabled ? module.storage[0].bucket_arn : ""
  s3_object_prefix   = format("%s/AWSLogs/*", local.s3_bucket_arn)
}
