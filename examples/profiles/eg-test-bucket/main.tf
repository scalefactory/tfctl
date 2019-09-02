module "bucket" {
  source = "../../modules/s3-bucket"
  name   = "${local.account_id}-${local.account["test_bucket_name"]}"
}
