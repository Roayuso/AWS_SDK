provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "example" {
  bucket = "myexamplebucketrobertoayusodatadogtest"
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_public_key" "mm_staging_public_key" {
  comment     = "magic mirror staging public key"
  encoded_key = file("public_key.pem")
  name        = "mm-staging-public-key"
}

resource "aws_cloudfront_key_group" "mm_staging_key_group" {
  comment = "magic mirror staging key group"
  items   = [aws_cloudfront_public_key.mm_staging_public_key.id]
  name    = "mm-staging-key-group"
}

resource "aws_cloudfront_origin_access_control" "mm_cf_oac" {
  name                              = "mm-cf-oac"
  description                       = "OAC for CloudFront distribution to MM S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}



resource "aws_cloudfront_distribution" "mm_cf_distribution" {
  origin {
    domain_name              = aws_s3_bucket.example.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.mm_cf_oac.id
    origin_id                = "s3"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Distribution for magic mirror staging bucket"

#   logging_config {
#     include_cookies = false
#     bucket          = "dd-cloudfront-logs-staging.s3.amazonaws.com"
#     prefix          = "files.magicmirror.staging.dog"
#   }

#   aliases = ["files.magicmirror.staging.dog"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    compress    = true
    min_ttl     = 0        # none
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year


    trusted_key_groups = [aws_cloudfront_key_group.mm_staging_key_group.id]
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

tags = {
    Environment = "staging"
    "Name"                           = "MM Staging CF Distribution"
    "Team"                           = "dependency-management"
    "distribution/tls/lemur.managed" = "true"
    "terraform.managed"              = "true"
    "terraform.module"               = "mm_cf_distribution"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.example.id
  policy = data.aws_iam_policy_document.my-cdn-cf-policy.json
}

data "aws_iam_policy_document" "my-cdn-cf-policy" {
  statement {
    sid = "AllowCloudFrontServicePrincipalRead"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]

    resources = [
        aws_s3_bucket.example.arn,
      "${aws_s3_bucket.example.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        "arn:aws:cloudfront::730335545012:distribution/${aws_cloudfront_distribution.mm_cf_distribution.id}"
      ]
    }
  }
}