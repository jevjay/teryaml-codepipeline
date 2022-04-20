variable "config" {
  type    = string
  default = "Path to the pipeline configuration file"
}

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

variable "shared_tags" {
  type        = map(any)
  description = "Additional user defiend resoirce tags"
  default     = {}
}
