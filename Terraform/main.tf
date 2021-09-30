terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.60.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "s3bucket" {
  acl           = "public-read"
  force_destroy = true
  website {
    index_document = "index.html"
    error_document = "index.html"
  }
  provisioner "local-exec" {
    command = "curl https://raw.githubusercontent.com/arnold-nowik/arnold-cloud-cv/master/html/index.html -o index.html && curl https://raw.githubusercontent.com/arnold-nowik/arnold-cloud-cv/master/html/style.css -o style.css && aws s3 cp index.html s3://${self.id} && aws s3 cp style.css s3://${self.id}/ && rm index.html style.css"
  }
}

resource "aws_cloudfront_origin_access_identity" "cf_oai" {
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.s3bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.cf_oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "StaticWebsiteBucketPolicy" {
  bucket = aws_s3_bucket.s3bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.s3bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cf_oai.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "WebsiteURL" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

