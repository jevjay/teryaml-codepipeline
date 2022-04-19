![Terrabits logo](./img/terrabits-logo.png)

# terraforest-codepipeline

Terraform based configuration for AWS Codepipeline based CI/CD stack

# Usage

Create a simple Codepipeline job integrated with AWS CodeCommit as a source

```hcl
module "codecommit_job" {
  source  = "github.com/jevjay/terraforest-codepipeline"

  repository_name = "my-repository"
  repository_url  = "https://git-codecommit.us-east-2.amazonaws.com/v1/repos/my-repository"
  pipeline_config = "./path/to/config.file"
```

# Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| repository\_name | Repository name to which Codebuild Job should be linked | string | n/a | yes |
| repository\_url | Repository URL, from which it source can be cloned | string | n/a | yes |
| pipeline\_config | Path to the pipeline configuration file | string | n/a | yes |
| default\_artifact\_store | Setup a default artifact store. Can be overwritten via pipeline config yaml `artifact_bucket` key | bool | false | no |
| default\_build\_cache\_store | Setup a default Codebuild job cache store. Can be overwritten via pipeline config yaml `build_cache_store_bucket` key | bool | false | no |
| tags | Additional user defiend resoirce tags | map(any) | \{\} | no |

# Outputs

| Name | Description |
|------|-------------|
| default\_pipeline\_artifact\_bucket\_arn | The ARN of the default codepipeline artifact store bucket ARN |
| default\_pipeline\_artifact\_bucket\_name | The name of the default codepipeline artifact store bucket ARN |
| default\_build\_cache\_store\_arn | The ARN of the default codebuild cache store bucket ARN |
| default\_build\_cache\_bucket\_name | The name of the default codebuild cache store bucket ARN |
| default\_pipeline\_role\_arn | Amazon Resource Name (ARN) specifying the default pipeline role |
| default\_pipeline\_role\_name | Name of the default pipeline role |
| default\_job\_role\_arn | Amazon Resource Name (ARN) specifying the default Codebuild job (stage action) role |
| default\_job\_role\_name | Name of the default Codebuild job (stage action) role |
| cloudwatch\_branch\_trigger\_arn | The Amazon Resource Name (ARN) of the Cloudwatch branch events trigger rule |
| cloudwatch\_branch\_trigger\_name | The name of the Cloudwatch branch events trigger rule |
| cloudwatch\_tag\_trigger\_arn | The Amazon Resource Name (ARN) of the Cloudwatch tag events trigger rule |
| cloudwatch\_tag\_trigger\_name | The name of the Cloudwatch tag events trigger rule |
| cloudwatch\_cron\_trigger\_arn | The Amazon Resource Name (ARN) of the Cloudwatch cron timer rule |
| cloudwatch\_cron\_trigger\_name | The name of the Cloudwatch cron timer rule |
| pipeline\_arn | The Amazon Resource Name (ARN) of AWS Codepipeline pipeline |
| pipeline\_name | The name of AWS Codepipeline pipeline |

## Authors

Originally created by [Jev Jay](https://github.com/jevjay)
Module managed by [Jev Jay](https://github.com/jevjay).

## License

Apache 2.0 licensed. See `LICENSE.md` for full details.
