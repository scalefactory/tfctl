module "bucket" {
  source = "../../modules/s3-bucket"
  name   = "${local.account_id}-${local.account["shared_bucket_name"]}"
}
