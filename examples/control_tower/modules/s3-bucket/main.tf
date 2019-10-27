resource aws_s3_bucket bucket {
  bucket = var.name
  acl    = "private"
}
