###############################################
#  Lambda – Scheduled Scaling                 #
###############################################
# IAM Role
resource "aws_iam_role" "lambda_role" {
  name               = "lambda-ecs-scale-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.project_tag
}
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_policy" "ecs_update_policy" {
  name   = "ecs-update-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["ecs:UpdateService", "ecs:DescribeServices"], Resource = "*" }]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_ecs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ecs_update_policy.arn
}

# Reusable Lambda source – zipped inline
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/scale_ecs.zip"

  source {
    filename = "lambda_function.py"
    content  = <<-PY
      import boto3, os
      ecs = boto3.client('ecs')
      CLUSTER = os.environ['CLUSTER']
      SERVICE = os.environ['SERVICE']
      DESIRED = int(os.environ['DESIRED'])
      def handler(event, context):
          ecs.update_service(cluster=CLUSTER, service=SERVICE, desiredCount=DESIRED)
          return {"status": "updated", "desired": DESIRED}
    PY
  }
}

# Lambda functions
resource "aws_lambda_function" "scale_to_1" {
  function_name = "scale-ecs-to-1"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 30
  environment {
    variables = {
      CLUSTER = aws_ecs_cluster.project.name
      SERVICE = aws_ecs_service.api.name
      DESIRED = 1
    }
  }
  tags = local.project_tag
}

resource "aws_lambda_function" "scale_to_2" {
  function_name = "scale-ecs-to-2"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 30
  environment {
    variables = {
      CLUSTER = aws_ecs_cluster.project.name
      SERVICE = aws_ecs_service.api.name
      DESIRED = 2
    }
  }
  tags = local.project_tag
}

# EventBridge schedules
resource "aws_cloudwatch_event_rule" "midnight" {
  name                = "scale-ecs-to-1-midnight"
  schedule_expression = "cron(0 0 * * ? *)" # 00:00 UTC
}
resource "aws_cloudwatch_event_target" "midnight_target" {
  rule      = aws_cloudwatch_event_rule.midnight.name
  target_id = "lambdaScaleTo1"
  arn       = aws_lambda_function.scale_to_1.arn
}
resource "aws_lambda_permission" "midnight_perm" {
  statement_id  = "AllowEventBridgeMidnight"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_to_1.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.midnight.arn
}

resource "aws_cloudwatch_event_rule" "morning" {
  name                = "scale-ecs-to-2-07"
  schedule_expression = "cron(0 7 * * ? *)" # 07:00 UTC
}
resource "aws_cloudwatch_event_target" "morning_target" {
  rule      = aws_cloudwatch_event_rule.morning.name
  target_id = "lambdaScaleTo2"
  arn       = aws_lambda_function.scale_to_2.arn
}
resource "aws_lambda_permission" "morning_perm" {
  statement_id  = "AllowEventBridgeMorning"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_to_2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.morning.arn
}