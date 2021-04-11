module "pr_validator" {
  source = "git@github.com:jevjay/terraforest-lambda.git?ref=v0.1.0"

  name          = local.name
  lambda_source = var.lambda_source
  runtime       = "go1.x"

  environment = [{
    variables = {
      STORE_BUCKET = aws_s3_bucket.store.id
    }
  }]

  lambda_additional_policies = {
    "${local.name}-additional-policy" = data.aws_iam_policy_document.additional_permissions.json
  }
}

data "aws_iam_policy_document" "additional_permissions" {
  statement {
    sid = "PRValidatorCodepipelineAccess"
    actions = [
      "codepipeline:UpdatePipeline",
      "codepipeline:StartPipelineExecution",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid = "AllowReadWriteToS3Store"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:List*",
    ]
    resources = [
      aws_s3_bucket.store.arn,
      "${aws_s3_bucket.store.arn}/*",
    ]
  }

  statement {
    sid = "AllowPassDefaultPipelineRole"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::341925873666:role/default-pipeline-role",
    ]
  }

  statement {
    sid = "AllowPRValidatorApprovingPRs"
    actions = [
      "codecommit:UpdatePullRequestApprovalState",
      "codecommit:PostCommentForPullRequest",
    ]
    resources = [
      "*"
    ]
  }
}

# Codecommit PR events Cloudwatch rule and Lambda mapping
resource "aws_cloudwatch_event_rule" "pr_event" {
  name        = "codecommit-pr-events"
  description = "Capture CodeCommit PR events for all CodeCommit repositories"

  event_pattern = <<PATTERN
{
  "detail": {
    "event": [
      "pullRequestCreated",
      "pullRequestSourceBranchUpdated"
    ]
  },
  "detail-type": [
    "CodeCommit Pull Request State Change"
  ],
  "source": [
    "aws.codecommit"
  ]
}
PATTERN
}

resource "aws_cloudwatch_event_target" "pr_event_trigger" {
  rule      = aws_cloudwatch_event_rule.pr_event.name
  target_id = "pr-status-lambda-trigger"
  arn       = module.pr_validator.lambda_arn
}

resource "aws_lambda_permission" "pr_event_trigger" {
  statement_id  = "AllowTriggerFromCodeCommitPREvents"
  action        = "lambda:InvokeFunction"
  function_name = "${local.name}-${terraform.workspace}"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.pr_event.arn
}

# Codebuild job status Cloudwatch rule and Lambda mapping
resource "aws_cloudwatch_event_rule" "pipeline_stage_status_event" {
  name        = "pipeline-stage-status"
  description = "Capture CodePipeline stage status events for all CodePipeline pipelines"

  event_pattern = <<PATTERN
{
  "detail": {
    "state": [
      "SUCCEEDED",
      "FAILED"
    ]
  },
  "detail-type": [
    "CodePipeline Pipeline Execution State Change"
  ],
  "source": [
    "aws.codepipeline"
  ]
}
PATTERN
}

resource "aws_cloudwatch_event_target" "pipeline_stage_status_event_trigger" {
  rule      = aws_cloudwatch_event_rule.pipeline_stage_status_event.name
  target_id = "pipeline-stage-status-lambda-trigger"
  arn       = module.pr_validator.lambda_arn
}

resource "aws_lambda_permission" "pipeline_stage_status_event_trigger" {
  statement_id  = "AllowTriggerFromCodepipelineStatus"
  action        = "lambda:InvokeFunction"
  function_name = "${local.name}-${terraform.workspace}"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.pipeline_stage_status_event.arn
}

resource "aws_s3_bucket" "store" {
  bucket = "${local.name}-${terraform.workspace}-store"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "simpleCleanup"
    enabled = true

    expiration {
      days = 7
    }
  }

  tags = local.common_tags
}
