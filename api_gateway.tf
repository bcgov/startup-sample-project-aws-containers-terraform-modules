resource "aws_api_gateway_vpc_link" "app" {
  name        = var.app_name
  description = "app VPC link for API gateway"
  subnet_ids  = module.network.aws_subnet_ids.web.ids
}

resource "aws_apigatewayv2_api" "app`" {
  name          = var.app_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "app" {
  api_id             = aws_apigatewayv2_api.app.id
  integration_type   = "HTTP_PROXY"
  connection_id      = aws_api_gateway_vpc_link.app.id
  connection_type    = "VPC_LINK"
  integration_method = "ANY"
  integration_uri    = aws_alb_listener.internal.arn
}

resource "aws_apigatewayv2_route" "app" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_stage" "app" {
  api_id      = aws_apigatewayv2_api.app.id
  name        = "$default"
  auto_deploy = true
}