locals {
  # === STORAGE (artifacts, cache) ===

  storage = try(yamldecode(file(var.config))["storage"], {})

  shared_artifacts = try(flatten([
    for i, storage in local.storage : [
      for j, bucket in storage.shared_artifacts_bucket : {
        name = bucket.name
      }
    ]
  ]), {})

  shared_cache = try(flatten([
    for i, storage in local.storage : [
      for j, bucket in storage.codebuild_cache_bucket: {
        name = bucket.name
      }
    ]
  ]))

  // Pipeline YAML config parser
  config = try(yamldecode(file(var.config))["pipeline"], {})

  # === TRIGGERS ===

  codecommit_triggers = try(flatten([
    for i, config in local.config : [
      for j, trigger in config.trigger : [
        for k, codecommit in trigger.codecommit : {
          pipeline_name = config.name
          type          = k
          repository    = trigger.repository
          branch        = lookup(trigger, "branch", "")
          tag           = lookup(trigger, "tag", "")
          cron          = lookup(trigger, "cron", "")
        }
      ]
    ]
  ]), {})

  cron_triggers = try(flatten([
    for i, config in local.config : [
      for j, trigger in config.trigger : [
        for k, cron in trigger.cron : {
          pipeline_name = config.name
          type          = "cron"
          expression    = cron.expression
        }
      ]
    ]
  ]), {})

  eventbridge_triggers = try(flatten([
    for i, config in local.config : [
      for j, trigger in config.trigger : [
        for k, eventbridge in trigger.eventbridge : {
          pipeline_name = config.name
          type          = "eventbridge"
          event_pattern = eventbridge.event_pattern
        }
      ]
    ]
  ]), {})


  sources_config = try(flatten([
    for pk, config in local.config : [
      for sk, source in config.sources : [
        for ak, action in source.actions : {
          pipeline_name     = config.name
          stage_name        = source.name
          name              = action.name
          owner             = action.owner
          provider          = action.provider
          version           = action.version
          repository_name   = action.repository_name
          deployment_branch = action.deployment_branch
          output_artifacts  = lookup(action, "output_artifacts", "source_out_artifacts")
          namespace         = lookup(action, "namespace", "SourceVariables")
        }
      ]
    ]
  ]), {})

  stages_config = try(flatten([
    for pk, config in local.config : [
      for sk, stage in config.stages : {
        pipeline_name    = config.name
        pipeline_trigger = config.trigger
        name             = stage.name
        order            = lookup(stage, "order", 1)
      }
    ]
  ]), {})

  actions_config = try(flatten([
    for pk, config in local.config : [
      for sk, stage in config.stages : [
        for ak, action in stage.actions : {
          pipeline_name            = config.name
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

  common_tags = merge(var.shared_tags, { Terraformed = true })
}
