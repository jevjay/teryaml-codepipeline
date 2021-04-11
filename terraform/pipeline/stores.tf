resource "aws_s3_bucket" "artifact_store" {
  count  = var.default_artifact_store ? 0 : 1
  bucket = local.default_artifact_store

  tags = local.common_tags
}

resource "aws_s3_bucket" "build_cache_store" {
  count  = var.default_build_cache_store ? 0 : 1
  bucket = local.default_build_cache_store

  tags = local.common_tags
}
