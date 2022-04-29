// CodeBuild resources configuration
module "codebuild_action" {
  source = "github.com:jevjay/terrabits-codebuild"

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
          variables : each.value.variables
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

module "lambda_action" {
  source = "github.com:jevjay/terrabits-lambda"

  for_each = try({ for a in local.actions_config : "${a.pipeline_name}-${a.stage_name}-${a.name}" => a if a.category == "Invoke" }, {})

  raw_config = yamlencode({
    config : [
      {
        name : each.key,
        handler : each.value.handler,
        runtime : each.value.runtime,
        source : each.value.source,
        architectures : each.value.architectures,
        code_signing_config_arn : each.value.code_signing_config_arn,
        description : each.value.description,
        memory : each.value.memory,
        timeout : each.value.timeout,
        variables : { for i in each.value.variables : i.name => i.value },
        vpc : {
          subnet_ids : each.value.vpc_subnets,
          security_group_ids : each.value.vpc_security_groups
        },
        permissions : {
          role : each.value.service_role,
          policy : each.value.service_role_policy
        },
        logs : {
          group_name : each.key
        }
      }
  ] })

  shared_tags = local.common_tags
}
