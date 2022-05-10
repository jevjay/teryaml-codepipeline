variable "config" {
  type    = string
  default = "Path to the pipeline configuration file"
}

variable "shared_tags" {
  type        = map(any)
  description = "Additional user defiend resoirce tags"
  default     = {}
}
