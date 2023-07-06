provider "aws" {
  region = "ca-central-1" # specify your region
}

locals {
  common_tags = {
    Environment = "test"
    Project     = "ecs-api-gateway"
  }
}
resource "aws_ecs_cluster" "main" {
  name               = "main-cluster"
  capacity_providers = ["FARGATE_SPOT"]
  default_capacity_provider_strategy {
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}
resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  container_definitions = jsonencode([
    {
      name = "app"
      image = "httpd:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "main" {

  name = "sample-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type = "FARGATE"
  desired_count = 1
 network_configuration {
    subnets          = ["subnet-0abcd1234ef56789", "subnet-0abcdef123456789"] # Replace with your actual subnet ids
    assign_public_ip = false
  }
  // keep or not
  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = module.network.aws_subnet_ids.app.ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api-target.arn
    container_name = "app"
    container_port = 80
  }
  depends_on = [aws_lb_listener.api-listener]
}

resource "aws_lb" "api-lb" {
  name = "api-lb"
  internal = true
  load_balancer_type = "network" # Change this to "network" for NLB
  subnets = ["subnet-0abcd1234ef56789", "subnet-0abcdef123456789"] # Replace with your actual subnet ids
  enable_cross_zone_load_balancing = true
  tags = local.common_tags

}

resource "aws_lb_target_group" "api-target" {
  name = "api-target"
  port = 80
  protocol = "TCP"
  vpc_id = "vpc-0abcdef123456789" # Replace with your actual VPC ID
  health_check {
    interval = 30
    protocol = "TCP"
    healthy_threshold = 3
    unhealthy_threshold = 3
    timeout = 6
  }
}

resource "aws_lb_listener" "api-listener" {
  load_balancer_arn = aws_lb.api-listener.arn
  port = "80"
  protocol = "TCP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.api-target.arn
  }
}

resource "aws_vpc_endpoint_service" "api-vpc" {
  acceptance_required = false
  network_load_balancer_arns = [aws_lb.example.arn]
}

resource "aws_api_gateway_vpc_link" "api-link" {
  name = "api-link"
  description = "example VPC link for API gateway"
  target_arns = [aws_vpc_endpoint_service.api-vpc.service_arn]
}

resource "aws_apigatewayv2_api" "api-app" {
  name = "api-app"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "api-intergration" {
  api_id = aws_apigatewayv2_api.api-intergration.id
  integration_type = "HTTP_PROXY"
  connection_id = aws_api_gateway_vpc_link.api-link.id
  connection_type = "VPC_LINK"
  integration_method = "ANY"
  integration_uri = aws_vpc_endpoint_service.api-vpc.service_name
}

resource "aws_apigatewayv2_route" "api-route" {
  api_id = aws_apigatewayv2_api.api-route.id
  route_key = "ANY /{proxy+}"
  target = "integrations/${aws_apigatewayv2_integration.api-intergration.id}"
}

resource "aws_apigatewayv2_stage" "api-stage" {
  api_id = aws_apigatewayv2_api.api-stage.id
  name = "$default"
  auto_deploy = true
}


