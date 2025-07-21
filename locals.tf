locals {
  project_tag = {
    HW = "project"
    MANAGED="terraform"
  }
  account_id = data.aws_caller_identity.current.account_id
}