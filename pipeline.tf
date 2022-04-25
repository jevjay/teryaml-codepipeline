# CodePipeline resources configuration
resource "aws_codepipeline" "pipeline" {
  for_each = try({ for p in local.config : p.name => p }, {})

  name = each.value.name

  role_arn = length(try(each.value.iam_role, "")) > 0 ? each.value.iam_role : aws_iam_role.default_pipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store[each.value.name].id
    type     = "S3"
  }

  stage {
    name = "Source"

    # Main pipeline source
    dynamic "action" {
      for_each = { for i in local.sources : i.name => i }

      content {
        name             = action.value.name
        category         = "Source"
        owner            = action.value.owner
        provider         = action.value.provider
        output_artifacts = action.output_artifacts
        version          = action.value.version
        namespace        = action.value.namespace

        configuration = {
          RepositoryName       = action.value.repository
          BranchName           = action.value.branch
          PollForSourceChanges = action.value.poll_for_changes
        }
      }
    }

    # Additional sources configuration
    dynamic "action" {
      for_each = { for s in local.additional_sources : s.name => s if each.value.name == s.pipeline_name }

      content {
        name             = action.value.name
        category         = "Source"
        owner            = action.value.owner
        provider         = action.value.provider
        output_artifacts = action.value.output_artifacts
        version          = action.value.version
        namespace        = action.value.namespace

        configuration = {
          RepositoryName       = action.value.repository
          BranchName           = action.value.branch
          PollForSourceChanges = action.value.poll_for_changes
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
            ProjectName   = module.job["${action.value.pipeline_name}-${action.value.stage_name}-${action.value.name}"].codebuild_project_name[0]
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

  depends_on = [
    module.job,
  ]
}

// CodeBuild resources configuration
module "job" {
  source = "git@github.com:jevjay/terrabits-codebuild.git"

  for_each = try({ for a in local.actions_config : "${a.pipeline_name}-${a.stage_name}-${a.name}" => a if a.category == "Build" }, {})

  raw_config = yamlencode({
    config : [
      {
        name : each.key,
        description : each.value.description,
        build_timeout : each.value.build_timeout,
        badge_enabled : each.value.badge_enabled,
        concurrent_build_limit : each.value.concurrent_build_limit,
        queued_timeout : each.value.queued_timeout,
        service_role : {
          name : each.value.service_role,
          policy : each.value.service_role_policy,
        },
        source : {
          type : "CODEPIPELINE",
          buildspec : each.value.buildspec_file,
          git_clone_depth : each.value.git_clone_depth
        },
        artifacts : {
          type : "CODEPIPELINE",
        },
        cache : {
          type : each.value.cache_type,
          modes : each.value.cache_modes,
          location : "${each.value.build_cache_store_bucket}/terrabits-${each.key}",
        },
        environment : {
          compute_type : each.value.build_compute_type,
          image : each.value.build_image,
          type : each.value.build_type,
          certificate : each.value.build_certificate,
          image_pull_credentials_type : each.value.build_image_pull_credentials_type,
          privileged_mode : each.value.build_privileged_mode,
          variables : lookup(local.variables, each.key, {})
        },
        vpc : {
          id : each.value.vpc_id,
          subnets : each.value.vpc_subnets,
          security_groups : each.value.vpc_security_groups
        }
      }
    ]
  })

  shared_tags = local.common_tags
}
