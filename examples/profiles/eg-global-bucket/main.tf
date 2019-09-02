module "bucket" {
  source = "../../modules/s3-bucket"
  name   = "${local.account_id}-${local.account["global_bucket_name"]}"
}
