## Configuration syntax

Configurations provided to the module retrieved from a configuration file (YAML-based format) with a following syntax

### Example (basic)

_Note: replace <<>> values with an actual configuration_

```yaml
config:
- name: dummy
  trigger:
    cron:
      expression: "cron(15 10 ? * 6L 2002-2005)"
  artifact_bucket:
    name: "terrabits-artifacts"
  cache_bucket:
    name: "terrabits-cache"
  sources:
    actions: 
      - name: github
        provider: GitHub
        repository: github-repo
        branch: main
        output_artifacts:
          - github-repo
      - name: bitbucket
        provider: Bitbucket
        repository: bitbucket-repo
        branch: main
        output_artifacts:
          - bitbucket-repo    
      - name: s3-bucket
        provider: s3
        bucket: unique-bucket-name
        object_key: "some/source"
        poll: true      
  stages:
  - name: compile
    order: 1
    actions:
      - name: app-build
        provider: CodeBuild
        run_order: 1
        input_artifacts: 
          - source_out_artifacts
        output_artifacts: 
          - app_build_out_artifacts
        build_compute_type: BUILD_GENERAL1_SMALL
        build_timeout: "60"
        build_image: aws/codebuild/standard:3.0
        buildspec_file: .buildspec/build.yml
        service_role: app-build  
```

### Overview

#### config

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| name | AWS Codepipeline pipeline (unique) name | string | n/a | yes |
| trigger | Pipeline trigger confgiration block | map(object) | {} | no |
| artifact_bucket | S3 bucket where AWS CodePipeline stores artifacts for a pipeline | map(object) | n/a | yes |
| cache_bucket | S3 bucket location where the AWS CodeBuild project(s) used by pipelines stores cached resources | map(object) | {} | no |
| sources | Pipeline source configuration block | map(object) | {} | no |
| stages | Pipeline stages configuration block | map(object) | {} | no |

#### config.trigger

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| codecommit | AWS Codecommit-based pipeline trigger(s) configuration block | map(object) | {} | no |
| cron | Cron-based pipeline trigger(s) configuration block | map(object) | {} | no |
| eventbridge | AWS Evenbridge-based pipeline trigger(s) configuration block | map(object) | {} | no |

#### config.trigger.codecommit

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| repository | AWS Codecommit repository name | string | n/a | yes |
| branch | Repository trigger branch name used as a pipeline trigger | string | "" | no |
| tag | Repository tag prefix used as a pipeline trigger | string | "" | no |

#### config.trigger.cron

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| expression | Cron expression (following Eventbridge cron expression syntax) used as a pipeline trigger | string | n/a | yes |

#### config.trigger.eventbridge

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| event_pattern | AWS Eventbridge pipeline trigger event(s) JSON pattern | string | n/a | yes |  

#### config.artifact_bucket

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| name | S3 bucket name used by pipeline as artifact store | string | n/a | yes |

#### config.cache_bucket

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| name | S3 bucket location used by pipeline AWS Codebuild projects as its cache store | string | n/a | yes |

#### config.sources

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| name | A unique pipeline source action name | string | n/a | yes |
| provider | A category defines what kind of source type should be used. Available values: `CodeCommit`, `GitHub`, `Bitbucket`, `GitHubEnterpriseServer`, `S3` | string | n/a | yes |
| repository | Source repository name | string | n/a | yes ( when provider set as: `CodeCommit`, `GitHub`, `Bitbucket`, `GitHubEnterpriseServer` ) |
| branch | Source repository branch name | string | n/a | yes ( when provider set as: `CodeCommit`, `GitHub`, `Bitbucket`, `GitHubEnterpriseServer` ) |
| bucket | Source S3 bucket name | string | n/a | yes ( when provider set as: `S3` ) |
| object_key | Source S3 object path | string | n/a | yes ( when provider set as: `S3` ) |
| poll | Flag, which tell pipeline to poll for source changes periodically | bool | false | no |
| output_artifacts | A list of artifact names to output. Output artifact names must be unique within a pipeline | list(string) | n/a | yes |
| output_artifacts_format | Specifies the source output artifact format. Can be either `CODEBUILD_CLONE_REF` or `CODE_ZIP` | string | "CODE_ZIP" | no |
| version | A string that identifies the source version | string | "1" | no |
| namespace | The namespace all output variables will be accessed from | string | "SourceVariables" | no |


#### config.stages

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| name | A unique pipeline stage name | string | n/a | yes |
| order | Stage action order index | int | 1 | no |
| actions | Stage actions configuration block | list(map(object)) | n/a | no |

#### config.stages.actions

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| name | A unique pipeline stage action name | string | n/a | yes |
| description | A stage action description | string | "" | no |
| provider | A category defines what kind of source type should be used. Available values: `CodeBuild`, `Lambda`, `Manual` | string | n/a | yes |
| run_order | A stage action run order index | int | 1 | no |
| input_artifacts |  A list of artifact names to be worked on | list(string) | n/a | yes |
| output_artifacts | A list of artifact names to output. Output artifact names must be unique within a pipeline | list(string) | n/a | yes |
| service_role | AWS IAM role used by stage action | string | n/a | no |
| service_role_policy | AWS IAM policy ( in JSON pattern format ) attached to the service role | string | n/a | no |
| version | A string that identifies the stage action version | string | "1" | no |
| vpc_id | VPC ID used by a stage action | string | "" | no |
| vpc_subnets | A list of VPC stage action configuration subnet IDs| list(string) | [] | no |
| vpc_security_groups | A list of VPC stage action security groups | list(string) | [] | no |
| variables | Stage action environment variables configuration block | map(object) | {} | no (works with `CodeBuild`, `Lambda` providers ) |
| build_compute_type | Information about the compute resources AWS Codebuild project will use. Valid values: `BUILD_GENERAL1_SMALL`, `BUILD_GENERAL1_MEDIUM`, `BUILD_GENERAL1_LARGE`, `BUILD_GENERAL1_2XLARGE` | string | "BUILD_GENERAL1_SMALL" | no (works with `CodeBuild` provider) |
| build_certificate | ARN of the S3 bucket, path prefix and object key that contains the PEM-encoded certificate | string | "" | no (works with `CodeBuild` provider) |
| build_image_pull_credentials_type | Type of credentials AWS CodeBuild uses to pull images in your build. Valid values: `CODEBUILD`, `SERVICE_ROLE` | string | n/a | no (works with `CodeBuild` provider) |
| build_image | Docker image to use for this build project | string | "aws/codebuild/standard:3.0" | no (works with `CodeBuild` provider) |
| build_timeout | Number of minutes, from 5 to 480 (8 hours), for AWS CodeBuild to wait until timing out any related build that does not get marked as completed | string | "10" | no (works with `CodeBuild` provider) |
| build_type | Type of build environment to use for related builds. Valid values: `LINUX_CONTAINER`, `LINUX_GPU_CONTAINER`, `WINDOWS_CONTAINER` (deprecated), `WINDOWS_SERVER_2019_CONTAINER`, `ARM_CONTAINER` | string | "LINUX_CONTAINER" | no (works with `CodeBuild` provider) |
| build_privileged_mode | Flag which enables running the Docker daemon inside a Docker container | bool | false | no (works with `CodeBuild` provider) |
| badge_enabled | Generates a publicly-accessible URL for the projects build badge | bool | false | no (works with `CodeBuild` provider) |
| concurrent_build_limit | Specify a maximum number of concurrent builds for action Codebuild project | int | n/a | no (works with `CodeBuild` provider) |
| git_clone_depth | Truncate git history to this many commits. Use 0 for a **full** checkout | int | 1 | no (works with `CodeBuild` provider) |
| queued_timeout | Number of minutes, from 5 to 480 (8 hours), a build is allowed to be queued before it times out | string | "60" | no (works with `CodeBuild` provider) |
| cache_type | Type of storage that will be used for the AWS CodeBuild project cache. Valid values: `NO_CACHE`, `LOCAL`, `S3` | string | "NO_CACHE" | no (works with `CodeBuild` provider) |
| cache_modes | Specifies settings that AWS CodeBuild uses to store and reuse build dependencies. Valid values: `LOCAL_SOURCE_CACHE`, `LOCAL_DOCKER_LAYER_CACHE`, `LOCAL_CUSTOM_CACHE` | string | n/a | no (works with `CodeBuild` provider) |
| buildspec_file | Build specification to use for Codebuild stage action project's related builds | string | ".buildspec/pipeline.yml" | no (works with `CodeBuild` provider) |
| build_cache_store_bucket | Location where stage action AWS CodeBuild project stores cached resources. For type `S3`, the value must be a valid S3 bucket name/prefix | string | "" | no (works with `CodeBuild` provider) |
| handler | Stage action AWS Lambda function entrypoint in your code | string | n/a | yes (works with `Lambda` provider) |
| source | Stage action path to the function's deployment package within the local filesystem | string | n/a | yes (works with `Lambda` provider) |
| runtime | Identifier of the stage action Lambda function's runtime | string | n/a | yes (works with `Lambda` provider) |
| architectures | Instruction set architecture for your Lambda function | list(string) | ["x86_64"] | no (works with `Lambda` provider) |
| code_signing_config_arn | To enable code signing for this function, specify the ARN of a code-signing configuration | string | n/a | no (works with `Lambda` provider) |
| memory | Amount of memory in MB your stage action Lambda function can use at runtime | int | 128 | no (works with `Lambda` provider) |
| timeout | Amount of time your stage action Lambda function has to run in seconds | int | 3 | no (works with `Lambda` provider) |
| user_params | Stage action Lambda function user parameters configuration | string | n/a | no (works with `Lambda` provider) |

#### config.stages.actions.variables

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| name | Environment variable name (key) | string | n/a | no (works with `CodeBuild`, `Lambda` provider) |
| value | Environment variable value | string | n/a | no (works with `CodeBuild`, `Lambda` provider) |
| type | Environment variable type | string | "PLAINTEXT" | no (works with `CodeBuild` provider) |
