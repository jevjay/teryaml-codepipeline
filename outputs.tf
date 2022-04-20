// Default module S3 buckets/stores outputs
output "pipeline_artifact_bucket_arn" {
  description = "The ARN of the default codepipeline artifact store bucket ARN"
  value = [
    for store in aws_s3_bucket.artifact_store : store.arn
  ]
}

output "pipeline_artifact_bucket_name" {
  description = "The name of the default codepipeline artifact store bucket ARN"
  value = [
    for store in aws_s3_bucket.artifact_store : store.id
  ]
}

output "build_cache_store_arn" {
  description = "The ARN of the default codebuild cache store bucket ARN"
  value = [
    for store in aws_s3_bucket.build_cache_store : store.arn
  ]
}

output "build_cache_bucket_name" {
  description = "The name of the default codebuild cache store bucket ARN"
  value = [
    for store in aws_s3_bucket.build_cache_store : store.id
  ]
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

// Pipeline resources (EventBrige) outputs
output "cloudwatch_branch_trigger_arn" {
  description = "The Amazon Resource Name (ARN) of the Cloudwatch branch events trigger rule"
  value = [
    for trigger in aws_cloudwatch_event_rule.branch_trigger : trigger.arn
  ]
}

output "cloudwatch_branch_trigger_name" {
  description = "The name of the Cloudwatch branch events trigger rule"
  value = [
    for trigger in aws_cloudwatch_event_rule.branch_trigger : trigger.id
  ]
}

output "cloudwatch_tag_trigger_arn" {
  description = "The Amazon Resource Name (ARN) of the Cloudwatch tag events trigger rule"
  value = [
    for trigger in aws_cloudwatch_event_rule.tag_trigger : trigger.arn
  ]
}

output "cloudwatch_tag_trigger_name" {
  description = "The name of the Cloudwatch tag events trigger rule"
  value = [
    for trigger in aws_cloudwatch_event_rule.tag_trigger : trigger.id
  ]
}

output "cloudwatch_cron_trigger_arn" {
  description = "The Amazon Resource Name (ARN) of the Cloudwatch cron timer rule"
  value = [
    for trigger in aws_cloudwatch_event_rule.cron_trigger : trigger.arn
  ]
}

output "cloudwatch_cron_trigger_name" {
  description = "The name of the Cloudwatch cron timer rule"
  value = [
    for trigger in aws_cloudwatch_event_rule.cron_trigger : trigger.id
  ]
}

// Pipeline resources (Codepipeline) outputs
output "pipeline_arn" {
  description = "The Amazon Resource Name (ARN) of AWS Codepipeline pipeline"
  value = [
    for pipeline in aws_codepipeline.pipeline : pipeline.arn
  ]
}

output "pipeline_name" {
  description = "The name of AWS Codepipeline pipeline"
  value = [
    for pipeline in aws_codepipeline.pipeline : pipeline.id
  ]
}
