resource "aws_codestarconnections_connection" "pipeline" {
  for_each = { for i in local.sources : "${i.pipeline_name}-${i.stage_name}-${i.name}" => i if contains(local.codestarconnection_providers, i.provider) }

  name          = each.key
  provider_type = each.value.provider
}

# CodePipeline resources configuration
resource "aws_codepipeline" "pipeline" {
  for_each = try({ for p in local.config : p.name => p }, {})

  name = each.value.name

  role_arn = length(try(each.value.iam_role, "")) > 0 ? each.value.iam_role : aws_iam_role.default_pipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store[each.value.name].id
    type     = "S3"
  }

  # === SOURCES ===

  stage {
    name = "Sources"

    # Codecommit source
    dynamic "action" {
      for_each = { for i in local.sources : "${i.pipeline_name}-${i.stage_name}-${i.name}" => i if i.provider == "CodeCommit" }

      content {
        name             = action.value.name
        category         = "Source"
        owner            = "AWS"
        provider         = action.value.provider
        output_artifacts = action.value.output_artifacts
        version          = action.value.version
        namespace        = action.value.namespace
        run_order        = action.value.run_order

        configuration = {
          RepositoryName       = action.value.repository
          BranchName           = action.value.branch
          PollForSourceChanges = action.value.poll
          OutputArtifactFormat = action.value.output_artifacts_format
        }
      }
    }

    dynamic "action" {
      for_each = { for i in local.sources : "${i.pipeline_name}-${i.stage_name}-${i.name}" => i if i.provider == "S3" }

      content {
        name             = action.value.name
        category         = "Source"
        owner            = action.value.owner
        provider         = action.value.provider
        output_artifacts = action.value.output_artifacts
        version          = action.value.version
        namespace        = action.value.namespace
        run_order        = action.value.run_order

        configuration = {
          S3Bucket             = action.value.bucket
          S3ObjectKey          = action.value.object_key
          PollForSourceChanges = action.value.poll
        }
      }
    }

    dynamic "action" {
      for_each = { for i in local.sources : "${i.pipeline_name}-${i.stage_name}-${i.name}" => i if i.provider == "ECR" }

      content {
        name             = action.value.name
        category         = "Source"
        owner            = "AWS"
        provider         = action.value.provider
        output_artifacts = action.value.output_artifacts
        version          = action.value.version
        namespace        = action.value.namespace
        run_order        = action.value.run_order

        configuration = {
          ImageTag       = action.value.image_tag
          RepositoryName = action.value.repository
        }
      }
    }

    dynamic "action" {
      for_each = { for i in local.sources : "${i.pipeline_name}-${i.stage_name}-${i.name}" => i if contains(local.codestarconnection_providers, i.provider) }

      content {
        name             = action.value.name
        category         = "Source"
        owner            = "AWS"
        provider         = "CodeStarSourceConnection"
        output_artifacts = action.value.output_artifacts
        version          = action.value.version
        namespace        = action.value.namespace
        run_order        = action.value.run_order

        configuration = {
          ConnectionArn        = aws_codestarconnections_connection.pipeline["${action.value.pipeline_name}-${action.value.stage_name}-${action.value.name}"].arn
          FullRepositoryId     = action.value.repository
          BranchName           = action.value.branch
          DetectChanges        = action.value.poll
          OutputArtifactFormat = action.value.output_artifacts_format
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
            ProjectName   = module.codebuild_action["${action.value.pipeline_name}-${action.value.stage_name}-${action.value.name}"].codebuild_project_name[0]
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
            FunctionName   = module.lambda_action["${action.value.pipeline_name}-${action.value.stage_name}-${action.value.name}"].lambda_id[0]
            UserParameters = action.value.user_params
          }
        }
      }
    }
  }

  tags = local.common_tags

  depends_on = [
    module.codebuild_action,
    module.lambda_action,
  ]
}
