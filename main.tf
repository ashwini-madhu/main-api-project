provider "aws" {
  region = "us-east-1"
}

# --- VPC and Networking ---

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "main_igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private_subnet_2"
  }
}

resource "aws_subnet" "private_subnet_3" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.13.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "private_subnet_3"
  }
}

resource "aws_subnet" "private_subnet_4" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.14.0/24"
  availability_zone = "us-east-1d"
  tags = {
    Name = "private_subnet_4"
  }
}

resource "aws_eip" "nat_eip" {
  tags = {
    Name = "nat_eip"
  }
}

resource "aws_nat_gateway" "main_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "main_nat_gw"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat_gw.id
  }
  tags = {
    Name = "private_route_table"
  }
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_route_table_association" "private_subnet_3_association" {
  subnet_id      = aws_subnet.private_subnet_3.id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_route_table_association" "private_subnet_4_association" {
  subnet_id      = aws_subnet.private_subnet_4.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "lambda_sg" {
  vpc_id      = aws_vpc.main_vpc.id
  name        = "lambda_sg"
  description = "Allow Lambda to access RDS and other resources"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  tags = {
    Name = "lambda_sg"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id      = aws_vpc.main_vpc.id
  name        = "rds_sg"
  description = "Allow Lambda to use RDS instances"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "Allow Lambda to access RDS"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic from RDS"
  }
  tags = {
    Name = "rds_sg"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id,
    aws_subnet.private_subnet_3.id,
    aws_subnet.private_subnet_4.id
  ]
  tags = {
    Name = "rds_subnet_group"
  }
}

resource "aws_secretsmanager_secret" "rds_credential" {
  name        = "rds_credential"
  description = "RDS credentials for Lambda function"
  tags = {
    Name = "rds_credential"
  }
}

resource "aws_secretsmanager_secret_version" "rds_credential_version" {
  secret_id     = aws_secretsmanager_secret.rds_credential.id
  secret_string = jsonencode({
    username = "admin"
    password = "rdsadminpassword"
  })
}

data "aws_secretsmanager_secret" "rds_credential" {
  name = aws_secretsmanager_secret.rds_credential.name
}

data "aws_secretsmanager_secret_version" "rds_credential_version" {
  secret_id = data.aws_secretsmanager_secret.rds_credential.id
}

resource "aws_db_instance" "main_rds" {
  identifier            = "main-rds-instance"
  engine                = "mysql"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_type          = "gp2"
  username              = jsondecode(data.aws_secretsmanager_secret_version.rds_credential_version.secret_string)["username"]
  password              = jsondecode(data.aws_secretsmanager_secret_version.rds_credential_version.secret_string)["password"]
  db_subnet_group_name  = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az              = false
  publicly_accessible   = false
  skip_final_snapshot   = true
  tags = {
    Name = "main_rds_instance"
  }
}

resource "aws_iam_policy" "lambda_secrets_vpc_policy" {
  name        = "lambda_secrets_vpc_policy"
  description = "Policy to allow Lambda to access RDS credentials in Secrets Manager and manage ENIs in VPC"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = aws_secretsmanager_secret.rds_credential.arn
      },
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_vpc_policy_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_secrets_vpc_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "my_lambda" {
  function_name = "mylambda_function"
  filename      = "${path.module}/lambda-package.zip"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec.arn
  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet_1.id,
      aws_subnet.private_subnet_2.id,
      aws_subnet.private_subnet_3.id,
      aws_subnet.private_subnet_4.id
    ]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  environment {
    variables = {
      RDS_SECRET_ARN = data.aws_secretsmanager_secret.rds_credential.arn
    }
  }
  source_code_hash = filebase64sha256("./lambda-package.zip")
  timeout          = 30
  memory_size      = 128
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "my_http_api"
  protocol_type = "HTTP"
  description   = "HTTP API for Lambda function"
  tags = {
    Name = "my_http_api"
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
  depends_on = [
    aws_apigatewayv2_api.http_api,
    aws_lambda_function.my_lambda
  ]
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.my_lambda.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
  integration_method     = "POST"
  depends_on = [
    aws_lambda_permission.apigw
  ]
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
  depends_on = [
    aws_apigatewayv2_route.default_route
  ]
}

output "api_gateway_url" {
  description = "The URL of the HTTP API Gateway"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.main_rds.address
}

