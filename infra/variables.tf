# variable "project_name" {
#   description = "Project/system name used in resource names & tags"
#   type        = string
#   default     = "taskmgr"
# }

# variable "env" {
#   description = "Environment (e.g., dev, staging, prod)"
#   type        = string
#   default     = "dev"
# }

variable "stage" {
  description = "Deployment stage (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "serverless-task-manager"
    Owner      = "platform"
    ManagedBy  = "Terraform"
    CostCenter = "eng"
  }
}

# # API logging retention (days)
# variable "log_retention_days" {
#   type    = number
#   default = 14
# }
