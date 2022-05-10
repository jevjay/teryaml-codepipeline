# Here are configuration for IAM resources such as:
#
# 1. an optional default Codepipeline role
# 2. an optional default Codebuild job role

# Default pipeline role & policies 
data "aws_iam_policy_document" "codepipeline-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "default_pipeline" {
  name               = "default_pipeline_role"
  path               = "/terraforest/"
  assume_role_policy = data.aws_iam_policy_document.codepipeline-assume-role-policy.json

  inline_policy {
    name   = "default_pipeline_policy"
    policy = data.aws_iam_policy_document.default_pipeline_policy.json
  }

  tags = local.common_tags
}

data "aws_iam_policy_document" "default_pipeline_policy" {
  statement {
    actions = [
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:UploadArchive",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:CancelUploadArchive",
      "codecommit:GetRepository",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:BatchGetBuildBatches",
      "codebuild:StartBuildBatch",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:DescribeImages"
    ]

    resources = ["*"]
  }
}
