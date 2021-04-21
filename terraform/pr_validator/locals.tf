locals {
  name      = "pr-validator"

  # Used for controlling access to EC2 nodes, budgets, etc
  common_tags = {
    var.tags,
    "Environment" = terraform.workspace,
    "Terraformed" = true
  }

}
