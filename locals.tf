locals {
  // Pipeline YAML config parser
  config = try(yamldecode(file(var.config))["config"], {})

  # === PIPELINE ===

  pipeline = try(flatten([
    for config in local.config : {
      pipeline_name = config.name

    }
  ]), {})

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

  # === STORAGE (artifacts, cache) ===

  shared_artifacts = try(flatten([
    for i, config in local.config : {
      pipeline_name = config.name
      name          = lookup(config.artifact_bucket, "name", null)
    }
  ]), {})

  shared_cache = try(flatten([
    for i, config in local.config : {
      pipeline_name = config.name
      name          = lookup(config.cache_bucket, "name", null)
    }
  ]), {})

  sources = flatten([
    for config in local.config : [
      for action in lookup(config.sources, "actions", []) : {
          # Required
          pipeline_name    = config.name
          stage_name       = "Sources"
          name             = action.name
          provider         = action.provider
          output_artifacts = lookup(action, "output_artifacts", null)
          # Optional
          bucket                  = lookup(action, "bucket", null)
          object_key              = lookup(action, "object_key", null)
          version                 = lookup(action, "version", "1")
          repository              = lookup(action, "repository", null)
          branch                  = lookup(action, "branch", "main")
          image_tag               = lookup(action, "image_tag", null)
          namespace               = lookup(action, "namespace", "SourceVariables")
          poll                    = lookup(action, "poll", false)
          output_artifacts_format = lookup(action, "output_artifacts_format", "CODE_ZIP")
          run_order               = lookup(action, "run_order", 1)
        }
    ]
  ])

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
          pipeline_name                     = config.name
          stage_name                        = stage.name
          name                              = action.name
          description                       = lookup(action, "description", "")
          category                          = action.category
          owner                             = action.owner
          provider                          = action.provider
          version                           = action.version
          run_order                         = lookup(action, "run_order", 1)
          input_artifacts                   = lookup(action, "input_artifacts", [])
          output_artifacts                  = lookup(action, "output_artifacts", [])
          build_compute_type                = lookup(action, "build_compute_type", "BUILD_GENERAL1_SMALL")
          build_certificate                 = lookup(action, "build_certificate", null)
          build_image_pull_credentials_type = lookup(action, "build_image_pull_credentials_type", null)
          build_image                       = lookup(action, "build_image", "aws/codebuild/standard:3.0")
          build_timeout                     = lookup(action, "build_timeout", "10")
          build_type                        = lookup(action, "build_type", "LINUX_CONTAINER")
          build_privileged_mode             = lookup(action, "build_priviledged_mode", false)
          badge_enabled                     = lookup(action, "badge_enabled", false)
          concurrent_build_limit            = lookup(action, "concurent_build_limit", null)
          git_clone_depth                   = lookup(action, "git_clone_depth", 1)
          queued_timeout                    = lookup(action, "queued_timeout", "60")
          cache_type                        = lookup(action, "cache_type", "NO_CACHE")
          cache_modes                       = lookup(action, "cache_modes", null)
          vpc_id                            = lookup(action, "vpc_id", "")
          vpc_subnets                       = lookup(action, "vpc_subnets", [])
          vpc_security_groups               = lookup(action, "vpc_security_groups", [])
          buildspec_file                    = lookup(action, "buildspec_file", ".buildspec/pipeline.yml")
          service_role                      = lookup(action, "service_role", "")
          service_role_policy               = lookup(action, "service_role_policy", "")
          function_name                     = lookup(action, "function_name", "")
          user_params                       = lookup(action, "user_params", "")
          build_cache_store_bucket          = lookup(action, "build_cache_store_bucket", "")
        }
      ]
    ]
  ]), {})

  variables = try(flatten([
    for config in local.config : [
      for stage in config.stages : {
        for i in lookup(stage.actions, "variables", []) : "${config.pipeline_name}-${stage.name}-${i.name}" => {
          name  = lookup(i.variables, "name", null)
          value = lookup(i.variables, "value", null)
          type  = lookup(i.variables, "type", null)
        }
      }
    ]
  ]), {})

  codestarconnection_providers = [
    "Bitbucket",
    "GitHub",
    "GitHubEnterpriseServer",
  ]

  common_tags = merge(var.shared_tags, { Terraformed = true })
}
