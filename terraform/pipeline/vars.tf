variable "repository_name" {
  type        = string
  description = "Source repository name"
}

variable "repository_arn" {
  type        = string
  description = "Source repository ARN"
}

variable "repository_url" {
  type        = string
  description = "Repository URL, from which it source can be cloned"
}

variable "pipeline_config" {
  type    = string
  default = "Path to the pipeline configuration file"
}

variable "default_artifact_store" {
  type        = bool
  description = "Setup a default artifact store. Can be overwritten via pipeline config yaml `artifact_bucket` key"
  default     = false
}

variable "default_build_cache_store" {
  type        = bool
  description = "Setup a default Codebuild job cache store. Can be overwritten via pipeline config yaml `build_cache_store_bucket` key"
  default     = false
}

variable "tags" {
  type        = map(any)
  description = "Additional user defiend resoirce tags"
  default     = {}
}
