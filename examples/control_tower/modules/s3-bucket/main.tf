resource aws_s3_bucket bucket {
  bucket = var.name
  acl    = "private"
}

output "arn" {
  value = aws_s3_bucket.bucket.arn
}
