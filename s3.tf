resource "random_pet" "upload_bucket_name" {
  prefix = "upload-bucket"
  length = 2
}

resource "aws_s3_bucket" "upload_bucket" {
  bucket        = random_pet.upload_bucket_name.id
  force_destroy = true
}

resource "aws_s3_bucket_acl" "upload_bucket_acl" {
  depends_on = [aws_s3_bucket.upload_bucket]
  bucket = aws_s3_bucket.upload_bucket.id
  acl    = "private"
}