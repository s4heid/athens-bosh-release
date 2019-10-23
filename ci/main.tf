variable "region" {
  type = "string"
  default = "eu-central-1"
}
variable "aws_access_key" {
  type = "string"
  description = "access key of aws account"
}
variable "aws_secret_key" {
  type = "string"
  description = "secret key of aws account"
}

variable "env_name" {
  type    = "string"
}

variable "vpc_id" {
  type    = "string"
}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

resource "aws_eip" "athens_eip" {
  vpc        = true
}

resource "aws_security_group" "athens_sg" {
  name        = "athens_sg"
  description = "Allow TLS inbound traffic on port 3000"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

output "external_ip" {
  value = "${aws_eip.athens_eip.public_ip}"
}

output "athens_security_group" {
  value = "${aws_security_group.athens_sg.id}"
}
