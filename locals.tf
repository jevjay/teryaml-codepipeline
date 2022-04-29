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
        owner                   = lookup(action, "owner", "AWS")
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
          # Shared
          pipeline_name       = config.name
          stage_name          = stage.name
          name                = action.name
          category            = lookup(local.categories, action.provider, null)
          owner               = lookup(local.owners, action.provider, null)
          provider            = action.provider
          description         = lookup(action, "description", "")
          version             = lookup(action, "version", "1")
          run_order           = lookup(action, "run_order", 1)
          input_artifacts     = lookup(action, "input_artifacts", [])
          output_artifacts    = lookup(action, "output_artifacts", [])
          service_role        = lookup(action, "service_role", "")
          service_role_policy = lookup(action, "service_role_policy", "")
          vpc_subnets         = lookup(action, "vpc_subnets", [])
          vpc_security_groups = lookup(action, "vpc_security_groups", [])
          variables = [
            for variable in local.variables : {
              name  = variable.name
              value = variable.value
              type  = variable.type
          } if variable.pipeline_name == config.name && variable.stage_name == stage.name && variable.action_name == action.name]

          # CodeBuild variables
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
          buildspec_file                    = lookup(action, "buildspec_file", ".buildspec/pipeline.yml")
          build_cache_store_bucket          = lookup(action, "build_cache_store_bucket", "")

          # Lambda variables
          handler                 = lookup(action, "handler", null)
          runtime                 = lookup(action, "runtime", null)
          source                  = lookup(action, "source", null)
          architectures           = lookup(action, "architectures", ["x86_64"])
          code_signing_config_arn = lookup(action, "code_signing_config_arn", null)
          memory                  = lookup(action, "memory", 128)
          timeout                 = lookup(action, "timeout", 3)
          user_params             = lookup(action, "user_params", "")
        }
      ]
    ]
  ]), {})

  variables = flatten([
    for config in local.config : [
      for stage in config.stages : [
        for action in stage.actions : [
          for i in lookup(action, "variables", []) : {
            pipeline_name = config.name
            stage_name    = stage.name
            action_name   = action.name
            name          = i.name
            value         = i.value
            type          = try(i.type, "PLAINTEXT")
          }
        ]
      ]
    ]
  ])

  codestarconnection_providers = [
    "Bitbucket",
    "GitHub",
    "GitHubEnterpriseServer",
  ]

  owners = {
    "CodeBuild"  = "AWS"
    "Lambda"     = "AWS"
    "CodeDeploy" = "AWS"
    "Manual"     = "AWS"
  }

  categories = {
    "CodeBuild"  = "Build"
    "Lambda"     = "Invoke"
    "CodeDeploy" = "Deploy"
    "Manual"     = "Approval"
  }

  common_tags = merge(var.shared_tags, { Terraformed = true })
}
