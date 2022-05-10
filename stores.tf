resource "aws_s3_bucket" "artifact_store" {
  for_each = try({ for i in local.shared_artifacts : i.pipeline_name => i }, {})

  bucket = each.value.name

  tags = local.common_tags
}

resource "aws_s3_bucket" "build_cache_store" {
  for_each = try({ for i in local.shared_cache : i.pipeline_name => i }, {})

  bucket = each.value.name

  tags = local.common_tags
}
