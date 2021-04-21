// Cloudwatch Events resources
//
// These section contains configuration for Cloudwatch events, which trigger pipeline
// based on the tracked events
data "aws_iam_policy_document" "event_assume" {
  count = length(local.pipeline_config) > 0 ? 1 : 0
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

// Configure Cloudwatch event IAM role(s)
resource "aws_iam_role" "event_role" {
  for_each = try({ for p in local.pipeline_config : p.name => p }, {})

  name               = "${var.repository_name}-${each.value.name}-pipeline"
  assume_role_policy = data.aws_iam_policy_document.event_assume[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "event_policy" {
  for_each = try({ for p in local.pipeline_config : p.name => p }, {})

  name   = "${var.repository_name}-${each.value.name}-events"
  role   = aws_iam_role.event_role[each.value.name].id
  policy = <<EOF
{
  "Statement": [
    {
      "Action": [
        "codepipeline:StartPipelineExecution"
      ],
      "Effect": "Allow",
      "Resource": "${aws_codepipeline.codepipeline[each.value.name].arn}"
    }
  ]
}
EOF
}

// Cloudwatch event for branch trigger
resource "aws_cloudwatch_event_rule" "branch_event" {
  for_each = try({ for s in local.sources_config : "${s.pipeline_name}-${s.name}" => s if s.pipeline_trigger == "branch" }, {})

  name        = "${each.value.name}-branch-trigger"
  description = "Capture CodeCommit merge to branch events for ${var.repository_name}"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codecommit"
  ],
  "detail-type": [
    "CodeCommit Repository State Change"
  ],
  "resources": [
    "${var.repository_arn}"
  ],
  "detail": {
    "referenceType": [
      "branch"
    ],
    "referenceName": [
      "${each.value.trigger_deployment_branch}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "branch_event_trigger" {
  for_each = try({ for s in local.sources_config : "${s.pipeline_name}-${s.name}" => s if s.pipeline_trigger == "branch" }, {})

  rule     = aws_cloudwatch_event_rule.branch_event["${each.value.pipeline_name}-${each.value.name}"].name
  role_arn = aws_iam_role.event_role[each.value.pipeline_name].arn
  arn      = aws_codepipeline.codepipeline[each.value.pipeline_name].arn
}
// Cloudwatch event for tag trigger
resource "aws_cloudwatch_event_rule" "tag_event" {
  for_each = try({ for s in local.sources_config : "${s.pipeline_name}-${s.name}" => s if s.pipeline_trigger == "tag" }, {})

  name        = "${each.value.name}-tag-trigger"
  description = "Capture CodeCommit merge to tag events for ${var.repository_name}"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codecommit"
  ],
  "detail-type": [
    "CodeCommit Repository State Change"
  ],
  "resources": [
    "${var.repository_arn}"
  ],
  "detail": {
    "referenceType": [
      "tag"
    ],
    "referenceName": [
      "${each.value.trigger_deployment_tag}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "tag_event_trigger" {
  for_each = try({ for s in local.sources_config : "${s.pipeline_name}-${s.name}" => s if s.pipeline_trigger == "tag" }, {})

  rule     = aws_cloudwatch_event_rule.tag_event["${each.value.pipeline_name}-${each.value.name}"].name
  role_arn = aws_iam_role.event_role[each.value.pipeline_name].arn
  arn      = aws_codepipeline.codepipeline[each.value.pipeline_name].arn
}
//  Cloudwatch event for cron based trigger
resource "aws_cloudwatch_event_rule" "cron_event" {
  for_each = try({ for s in local.sources_config : "${s.pipeline_name}-${s.name}" => s if s.pipeline_trigger == "cron" }, {})

  name                = "${each.value.name}-cron-trigger"
  description         = "Capture cron deployment trigger events for ${var.repository_name}"
  schedule_expression = each.value.trigger_deployment_cron_expression
}

resource "aws_cloudwatch_event_target" "cron_event_trigger" {
  for_each = try({ for s in local.sources_config : "${s.pipeline_name}-${s.name}" => s if s.pipeline_trigger == "cron" }, {})

  rule     = aws_cloudwatch_event_rule.cron_event["${each.value.pipeline_name}-${each.value.name}"].name
  role_arn = aws_iam_role.event_role[each.value.pipeline_name].arn
  arn      = aws_codepipeline.codepipeline[each.value.pipeline_name].arn
}
// CodePipeline resources configuration
resource "aws_codepipeline" "pipeline" {
  for_each = try({ for p in local.pipeline_config : p.name => p }, {})

  name = "${var.repository_name}-${each.value.name}"

  role_arn = length(try(each.value.iam_role, "")) > 0 ? each.value.iam_role : aws_iam_role.default_pipeline.arn

  artifact_store {
    location = length(try(each.value.artifact_bucket, "")) > 0 ? each.value.artifact_bucket : aws_s3_bucket.artifact_store.id
    type     = "S3"
  }

  stage {
    name = "Source"

    dynamic "action" {
      for_each = { for s in local.sources_config : "${s.pipeline_name}-${s.name}" => s if each.value.name == s.pipeline_name }

      content {
        name             = action.value.name
        category         = "Source"
        owner            = action.value.owner
        provider         = action.value.provider
        output_artifacts = action.value.output_artifacts
        version          = action.value.version
        namespace        = action.value.namespace

        configuration = {
          RepositoryName       = action.value.repository_name
          BranchName           = action.value.deployment_branch
          PollForSourceChanges = "false"
        }
      }
    }
  }


  dynamic "stage" {
    for_each = { for i, s in local.stages_config : "${s.order}-${s.pipeline_name}-${s.name}" => s if each.value.name == s.pipeline_name }
    content {
      name = stage.value.name
      dynamic "action" {

        for_each = { for a in local.actions_config : "${a.pipeline_name}-${a.name}" => a if each.value.name == a.pipeline_name && stage.value.name == a.stage_name && a.category == "Build" }

        content {
          name             = action.value.name
          category         = action.value.category
          owner            = action.value.owner
          provider         = action.value.provider
          input_artifacts  = action.value.input_artifacts
          output_artifacts = action.value.output_artifacts
          version          = action.value.version
          run_order        = action.value.run_order

          configuration = {
            ProjectName   = module.job["${action.value.pipeline_name}-${action.value.name}"].codebuild_job_name[0]
            PrimarySource = action.value.input_artifacts[0]
            EnvironmentVariables = jsonencode([
              {
                name  = "SOURCE_BRANCH_NAME"
                value = "#{SourceVariables.BranchName}"
                type  = "PLAINTEXT"
              },
              {
                name  = "SOURCE_COMMIT_ID"
                value = "#{SourceVariables.CommitId}"
                type  = "PLAINTEXT"
              },
              {
                name  = "SOURCE_REPOSITORY_NAME"
                value = "#{SourceVariables.RepositoryName}"
                type  = "PLAINTEXT"
              },
              {
                name  = "PIPELINE_EXEC_ID"
                value = "#{codepipeline.PipelineExecutionId}"
                type  = "PLAINTEXT"
              },
            ])
          }
        }
      }

      dynamic "action" {

        for_each = { for a in local.actions_config : "${a.pipeline_name}-${a.name}" => a if each.value.name == a.pipeline_name && stage.value.name == a.stage_name && a.category == "Approval" }

        content {
          name     = action.value.name
          category = action.value.category
          owner    = action.value.owner
          provider = action.value.provider
          version  = action.value.version
        }
      }

      dynamic "action" {

        for_each = { for a in local.actions_config : "${a.pipeline_name}-${a.name}" => a if each.value.name == a.pipeline_name && stage.value.name == a.stage_name && a.provider == "Lambda" }

        content {
          name             = action.value.name
          category         = action.value.category
          owner            = action.value.owner
          provider         = action.value.provider
          input_artifacts  = action.value.input_artifacts
          output_artifacts = action.value.output_artifacts
          version          = action.value.version
          run_order        = action.value.run_order

          configuration = {
            FunctionName   = action.value.function_name
            UserParameters = action.value.user_params
          }
        }
      }
    }
  }

  tags = local.common_tags
}

// CodeBuild resources configuration
module "job" {
  source = "git@github.com:jevjay/terraforest-codebuild.git?ref=v0.0.1"

  for_each = try({ for a in local.actions_config : "${a.pipeline_name}-${a.name}" => a if a.category == "Build" }, {})

  enable_module                 = length(local.pipeline_config) > 0
  repository_name               = var.repository_name
  repository_arn                = var.repository_arn
  repository_url                = var.repository_url
  job_build_compute_type        = each.value.job_build_compute_type
  vpc_id                        = each.value.vpc_id
  vpc_subnets                   = each.value.vpc_subnets
  vpc_security_groups           = each.value.vpc_security_groups
  job_name                      = "${each.value.pipeline_name}-${each.value.name}"
  buildspec_file                = each.value.buildspec_file
  job_build_privileged_override = true
  job_build_timeout             = each.value.job_build_timeout
  job_iam_role                  = length(each.value.job_iam_role) > 0 ? each.value.job_iam_role : aws_iam_role.default_job.arn
  job_build_image               = each.value.job_build_image
  enable_s3_cache               = try(each.value.enable_cache, false)
  s3_cache_location             = length(each.value.build_cache_store_bucket) > 0 ? "${each.value.build_cache_store_bucket}/${var.repository_name}-${each.value.name}" : "${aws_s3_bucket.build_cache_store.id}/${var.repository_name}-${each.value.name}"
  tags                          = local.common_tags
}
