###############################################
#  ECS Cluster, Task Definition & Service     #
###############################################
resource "aws_ecs_cluster" "project" {
  name = "project-cluster"
  tags = local.project_tag
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/API-service"
  retention_in_days = 5
  tags              = local.project_tag
}

# Execution/Task role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.project_tag
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
# Allow Parameter Store reads
resource "aws_iam_policy" "ssm_read" {
  name   = "ecs-ssm-read"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["ssm:GetParameters", "ssm:GetParameter"], Resource = "arn:aws:ssm:eu-north-1:${local.account_id}:parameter/project/*" }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_ssm_read_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

resource "aws_ecs_task_definition" "api" {
  family                   = "API-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "307987835663.dkr.ecr.eu-north-1.amazonaws.com/goit/api-service:2"
      cpu       = 256
      memory    = 512
      portMappings = [{ containerPort = 80, hostPort = 80, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/API-service"
          awslogs-region        = "eu-north-1"
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:80/api/categories || exit 1"],
        interval    = 10,
        timeout     = 5,
        retries     = 3,
        startPeriod = 30
      }
      runtimePlatform = {
        cpuArchitecture       = "X86_64",
        operatingSystemFamily = "LINUX"
      }
      secrets = [
        for k in keys(local.ssm_params) : {
          name      = k
          valueFrom = aws_ssm_parameter.params[k].arn
        }
      ]
    }
  ])
  tags = local.project_tag
}

###############################################
#  ECS Service & Autoscaling                 #
###############################################
resource "aws_ecs_service" "api" {
  name            = "API-service-svc"
  cluster         = aws_ecs_cluster.project.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.api_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_tg.arn
    container_name   = "api"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.api_listener]
  tags       = local.project_tag
}

# CPU Target Tracking (>=70%)
resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.project.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_target" {
  name               = "cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value                     = 70
    scale_in_cooldown               = 300
    scale_out_cooldown              = 300
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
