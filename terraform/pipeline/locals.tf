locals {
  // Default values
  default_artifact_store    = "terraforest-codepipeline-artifact-store"
  default_build_cache_store = "terraforest-codepipeline-cache-store"

  // Pipeline YAML config parser
  pipeline_config = try(yamldecode(file(var.pipeline_config))["pipeline"], {})

  sources_config = try(flatten([
    for pk, pipeline in local.pipeline_config : [
      for sk, source in pipeline.sources : [
        for ak, action in source.actions : {
          pipeline_name                      = pipeline.name
          pipeline_trigger                   = lookup(pipeline, "trigger", "none")
          trigger_deployment_branch          = lookup(pipeline, "deployment_branch", "")
          trigger_deployment_cron_expression = lookup(pipeline, "deployment_cron_expression", "")
          trigger_deployment_tag             = lookup(pipeline, "deployment_tag", "")
          stage_name                         = source.name
          name                               = action.name
          owner                              = action.owner
          provider                           = action.provider
          version                            = action.version
          repository_name                    = action.repository_name
          deployment_branch                  = action.deployment_branch
          output_artifacts                   = lookup(action, "output_artifacts", "source_out_artifacts")
          namespace                          = lookup(action, "namespace", "SourceVariables")
        }
      ]
    ]
  ]), {})

  stages_config = try(flatten([
    for pk, pipeline in local.pipeline_config : [
      for sk, stage in pipeline.stages : {
        pipeline_name    = pipeline.name
        pipeline_trigger = pipeline.trigger
        name             = stage.name
        order            = lookup(stage, "order", 1)
      }
    ]
  ]), {})

  actions_config = try(flatten([
    for pk, pipeline in local.pipeline_config : [
      for sk, stage in pipeline.stages : [
        for ak, action in stage.actions : {
          pipeline_name            = pipeline.name
          pipeline_trigger         = pipeline.trigger
          stage_name               = stage.name
          name                     = action.name
          category                 = action.category
          owner                    = action.owner
          provider                 = action.provider
          version                  = action.version
          run_order                = lookup(action, "run_order", 1)
          input_artifacts          = lookup(action, "input_artifacts", [])
          output_artifacts         = lookup(action, "output_artifacts", [])
          job_build_compute_type   = lookup(action, "job_build_compute_type", "BUILD_GENERAL1_SMALL")
          vpc_id                   = lookup(action, "vpc_id", "")
          vpc_subnets              = lookup(action, "vpc_subnets", [])
          vpc_security_groups      = lookup(action, "vpc_security_groups", [])
          buildspec_file           = lookup(action, "buildspec_file", ".buildspec/pipeline.yml")
          job_build_timeout        = lookup(action, "job_build_timeout", "10")
          job_iam_role             = lookup(action, "job_iam_role", "")
          job_build_image          = lookup(action, "job_build_image", "aws/codebuild/standard:3.0")
          function_name            = lookup(action, "function_name", "")
          user_params              = lookup(action, "user_params", "")
          build_cache_store_bucket = lookup(action, "build_cache_store_bucket", "")
        }
      ]
    ]
  ]), {})

  common_tags = {
    var.tags,
    "Environment" = terraform.workspace,
    "Terraformed" = true
  }
}
