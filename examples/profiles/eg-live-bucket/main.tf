module "bucket" {
  source = "../../modules/s3-bucket"
  name   = "${local.account_id}-${local.account["live_bucket_name"]}"
}
