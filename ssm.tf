###############################################
#  SSM Parameter Store – App Config           #
###############################################
locals {
  ssm_params = {
    DATABASE_DIALECT      = "postgres"
    DATABASE_HOST         = aws_db_instance.postgres.address
    DATABASE_PORT         = "5432"
    DATABASE_NAME         = aws_db_instance.postgres.db_name
    DATABASE_USER         = aws_db_instance.postgres.username
    DATABASE_PASSWORD     = aws_db_instance.postgres.password
    JWT_SECRET            = "a7a633e7-9e7c-43cf-9624-8820e386627f"
    CLOUDINARY_API_KEY    = "XXX"
    CLOUDINARY_API_SECRET = "XXX"
    CLOUDINARY_CLOUD_NAME = "XXX"
    APP_URL               = "http://${aws_lb.api.dns_name}"
  }
}

resource "aws_ssm_parameter" "params" {
  for_each = local.ssm_params
  name     = "/project/${each.key}"
  type     = contains(["DATABASE_PASSWORD", "JWT_SECRET", "CLOUDINARY_API_SECRET"], each.key) ? "SecureString" : "String"
  value    = each.value
  tags     = local.project_tag
}
