provider "aws" {
  region = var.region
}

module "s3_aws_config" {
  source = "../../"

  force_destroy = true

  context = module.this.context
}
