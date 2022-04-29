# Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| repository\_name | Repository name to which Codebuild Job should be linked | string | n/a | yes |
| repository\_url | Repository URL, from which it source can be cloned | string | n/a | yes |
| pipeline\_config | Path to the pipeline configuration file | string | n/a | yes |
| default\_artifact\_store | Setup a default artifact store. Can be overwritten via pipeline config yaml `artifact_bucket` key | bool | false | no |
| default\_build\_cache\_store | Setup a default Codebuild job cache store. Can be overwritten via pipeline config yaml `build_cache_store_bucket` key | bool | false | no |
| tags | Additional user defiend resoirce tags | map(any) | \{\} | no |
