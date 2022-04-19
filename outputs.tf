// Default module S3 buckets/stores outputs
output "default_pipeline_artifact_bucket_arn" {
  value       = aws_s3_bucket.artifact_store.arn
  description = "The ARN of the default codepipeline artifact store bucket ARN"
}

output "default_pipeline_artifact_bucket_name" {
  value       = aws_s3_bucket.artifact_store.id
  description = "The name of the default codepipeline artifact store bucket ARN"
}

output "default_build_cache_store_arn" {
  value       = aws_s3_bucket.build_cache_store.arn
  description = "The ARN of the default codebuild cache store bucket ARN"
}

output "default_build_cache_bucket_name" {
  value       = aws_s3_bucket.build_cache_store.id
  description = "The name of the default codebuild cache store bucket ARN"
}

// Default module IAM resources outputs
output "default_pipeline_role_arn" {
  value       = aws_iam_role.default_pipeline.arn
  description = "Amazon Resource Name (ARN) specifying the default pipeline role"
}

output "default_pipeline_role_name" {
  value       = aws_iam_role.default_pipeline.id
  description = "Name of the default pipeline role"
}

output "default_job_role_arn" {
  value       = aws_iam_role.default_job.arn
  description = "Amazon Resource Name (ARN) specifying the default Codebuild job (stage action) role"
}

output "default_job_role_name" {
  value       = aws_iam_role.default_job.id
  description = "Name of the default Codebuild job (stage action) role"
}

// Pipeline resources (EventBrige) outputs
output "cloudwatch_branch_trigger_arn" {
  value       = aws_cloudwatch_event_rule.branch_event.arn
  description = "The Amazon Resource Name (ARN) of the Cloudwatch branch events trigger rule"
}

output "cloudwatch_branch_trigger_name" {
  value       = aws_cloudwatch_event_rule.branch_event.id
  description = "The name of the Cloudwatch branch events trigger rule"
}

output "cloudwatch_tag_trigger_arn" {
  value       = aws_cloudwatch_event_rule.tag_event.arn
  description = "The Amazon Resource Name (ARN) of the Cloudwatch tag events trigger rule"
}

output "cloudwatch_tag_trigger_name" {
  value       = aws_cloudwatch_event_rule.tag_event.id
  description = "The name of the Cloudwatch tag events trigger rule"
}

output "cloudwatch_cron_trigger_arn" {
  value       = aws_cloudwatch_event_rule.cron_event.arn
  description = "The Amazon Resource Name (ARN) of the Cloudwatch cron timer rule"
}

output "cloudwatch_cron_trigger_name" {
  value       = aws_cloudwatch_event_rule.cron_event.id
  description = "The name of the Cloudwatch cron timer rule"
}

// Pipeline resources (Codepipeline) outputs
output "pipeline_arn" {
  value       = aws_codepipeline.pipeline.arn
  description = "The Amazon Resource Name (ARN) of AWS Codepipeline pipeline"
}

output "pipeline_name" {
  value       = aws_codepipeline.pipeline.id
  description = "The name of AWS Codepipeline pipeline"
}