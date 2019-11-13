variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "env_name" {
  type    = string
  default = "athens-proxy"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zone" {
  type    = string
  default = "eu-central-1a"
}

provider "aws" {
  region = var.region
}

#
# iam
#

resource "aws_iam_user" "ci" {
  name = "${var.env_name}-ci"
}

resource "aws_iam_access_key" "ci" {
  user = aws_iam_user.ci.name
}

resource "aws_iam_user_policy" "ci_ro" {
  name = "${var.env_name}-policy"
  user = "${aws_iam_user.ci.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:*",
        "iam:*",
        "s3:*",
        "elasticloadbalancing:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

output "athens_access_key" {
  value = aws_iam_access_key.ci.id
}

output "athens_secret_key" {
  value     = aws_iam_access_key.ci.secret
  sensitive = true
}

#
# vpc
#

resource "aws_eip" "athens_eip" {
  vpc = true

  tags = {
    Name = var.env_name
  }
}

resource "aws_security_group" "athens_sg" {
  name        = "athens_sg"
  description = "Allow TLS inbound traffic on port 3000"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.env_name
  }
}

data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

resource "aws_subnet" "athens_subnet" {
  vpc_id            = var.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 144)
  availability_zone = var.availability_zone
  depends_on        = [data.aws_internet_gateway.default]

  tags = {
    Name = var.env_name
  }
}

resource "aws_route_table" "athens_route_table" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default.id
  }

  tags = {
    Name = var.env_name
  }
}

resource "aws_route_table_association" "athens_route_table_association" {
  subnet_id      = aws_subnet.athens_subnet.id
  route_table_id = aws_route_table.athens_route_table.id
}

output "athens_subnet_cidr" {
  value = aws_subnet.athens_subnet.cidr_block
}

output "athens_subnet_id" {
  value = aws_subnet.athens_subnet.id
}

output "external_ip" {
  value = aws_eip.athens_eip.public_ip
}

output "athens_security_group" {
  value = aws_security_group.athens_sg.id
}

#
# s3
#

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.env_name}-blobs"
  versioning {
    enabled = true
  }
}

data "aws_iam_policy_document" "public_read" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    effect = "Allow"
    principals {
      type = "*"
      identifiers = [
        "*",
      ]
    }
    resources = [
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.public_read.json
}

data "aws_iam_policy_document" "ci_s3" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}

resource "aws_iam_user_policy" "ci_s3" {
  name   = "s3"
  user   = aws_iam_user.ci.name
  policy = data.aws_iam_policy_document.ci_s3.json
}
