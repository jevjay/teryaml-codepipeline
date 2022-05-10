# === TRIGGERS & their supporting resources ===
#
# These section contains configuration for triggers, which trigger pipeline
# execution based on the tracked events

data "aws_iam_policy_document" "event_assume" {
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

# Configure Cloudwatch event IAM role(s)
resource "aws_iam_role" "event_role" {
  for_each = try({ for p in local.config : p.name => p }, {})

  name               = "terrabits-${each.value.name}"
  assume_role_policy = data.aws_iam_policy_document.event_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "event_policy" {
  for_each = try({ for p in local.config : p.name => p }, {})

  name   = "${each.value.name}-events"
  role   = aws_iam_role.event_role[each.value.name].id
  policy = <<EOF
{
  "Statement": [
    {
      "Action": [
        "codepipeline:StartPipelineExecution"
      ],
      "Effect": "Allow",
      "Resource": "${aws_codepipeline.pipeline[each.value.name].arn}"
    }
  ]
}
EOF
}

data "aws_codecommit_repository" "codecommit_trigger" {
  for_each = try({ for t in local.codecommit_triggers : t.repository => t }, {})

  repository_name = each.value.repository
}

# === (Codecommit) BRANCH triggers ===
#
# Codecommit branch update Eventbridge pipeline trigger

resource "aws_cloudwatch_event_rule" "branch_trigger" {
  for_each = try({ for t in local.codecommit_triggers : "${t.pipeline_name}-${t.type}" => t if t.type == "branch" }, {})

  name        = "${each.key}-trigger"
  description = "Capture CodeCommit merge to branch events for ${each.value.repository}"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codecommit"
  ],
  "detail-type": [
    "CodeCommit Repository State Change"
  ],
  "resources": [
    "${data.aws_codecommit_repository.codecommit_trigger[each.value.repository].arn}"
  ],
  "detail": {
    "referenceType": [
      "branch"
    ],
    "referenceName": [
      "${each.value.branch}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "branch_trigger" {
  for_each = try({ for t in local.codecommit_triggers : "${t.pipeline_name}-${t.type}" => t if t.type == "branch" }, {})

  rule     = aws_cloudwatch_event_rule.branch_trigger["${each.value.pipeline_name}-${each.value.type}"].name
  role_arn = aws_iam_role.event_role[each.value.pipeline_name].arn
  arn      = aws_codepipeline.pipeline[each.value.pipeline_name].arn
}

# === (Codecommit) TAG triggers ===
#
# Codecommit tag update Eventbridge pipeline trigger

resource "aws_cloudwatch_event_rule" "tag_trigger" {
  for_each = try({ for t in local.codecommit_triggers : "${t.pipeline_name}-${t.type}" => t if t.type == "tag" }, {})

  name        = "${each.key}-trigger"
  description = "Capture CodeCommit merge to tag events for ${each.value.repository}"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codecommit"
  ],
  "detail-type": [
    "CodeCommit Repository State Change"
  ],
  "resources": [
    "${data.aws_codecommit_repository.codecommit_trigger[each.value.repository].arn}"
  ],
  "detail": {
    "referenceType": [
      "tag"
    ],
    "referenceName": [
      "${each.value.tag}"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "tag_trigger" {
  for_each = try({ for t in local.codecommit_triggers : "${t.pipeline_name}-${t.type}" => t if t.type == "tag" }, {})

  rule     = aws_cloudwatch_event_rule.tag_trigger["${each.value.pipeline_name}-${each.value.type}"].name
  role_arn = aws_iam_role.event_role[each.value.pipeline_name].arn
  arn      = aws_codepipeline.pipeline[each.value.pipeline_name].arn
}

#  === CRON triggers ===
#
# Cron-based Eventbridge pipeline trigger

resource "aws_cloudwatch_event_rule" "cron_trigger" {
  for_each = try({ for t in local.cron_triggers : "${t.pipeline_name}-${t.type}" => t }, {})

  name                = "${each.key}-trigger"
  description         = "Capture cron trigger events for ${each.value.pipeline_name} pipeline"
  schedule_expression = each.value.expression
}

resource "aws_cloudwatch_event_target" "cron_trigger" {
  for_each = try({ for t in local.cron_triggers : "${t.pipeline_name}-${t.type}" => t }, {})

  rule     = aws_cloudwatch_event_rule.cron_trigger["${each.value.pipeline_name}-${each.value.type}"].name
  role_arn = aws_iam_role.event_role[each.value.pipeline_name].arn
  arn      = aws_codepipeline.pipeline[each.value.pipeline_name].arn
}

#  === EVENTBRIDGE triggers ===
#
# Custom Eventbridge event pipeline trigger

resource "aws_cloudwatch_event_rule" "eventbridge_trigger" {
  for_each = try({ for t in local.eventbridge_triggers : "${t.pipeline_name}-${t.type}" => t }, {})

  name        = "${each.key}-trigger"
  description = "Capture Eventbridge custom event for ${each.value.pipeline_name} pipeline"

  event_pattern = each.value.event_pattern
}

resource "aws_cloudwatch_event_target" "eventbridge_trigger" {
  for_each = try({ for t in local.eventbridge_triggers : "${t.pipeline_name}-${t.type}" => t }, {})

  rule     = aws_cloudwatch_event_rule.eventbridge_trigger["${each.value.pipeline_name}-${each.value.type}"].name
  role_arn = aws_iam_role.event_role[each.value.pipeline_name].arn
  arn      = aws_codepipeline.pipeline[each.value.pipeline_name].arn
}
