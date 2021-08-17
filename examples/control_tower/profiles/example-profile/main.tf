resource "random_pet" "bucket_prefix" {
}

module "bucket" {
  source = "../../modules/s3-bucket"
  name   = "${random_pet.bucket_prefix.id}-${local.account["data"]["example_bucket_name"]}"
}

output "bucket_arn" {
  value = module.bucket.arn
}
