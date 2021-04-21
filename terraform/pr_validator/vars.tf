variable "lambda_source" {
  type        = string
  description = "Path to Lambda function source archive"
}

variable "tags" {
  type        = map
  description = "Additional user defiend resoirce tags"
  default     = {}
}
