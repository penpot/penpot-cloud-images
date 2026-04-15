packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_name_prefix" {
  type    = string
  default = "penpot-cloud-image-aws"
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type    = string
  default = ""
}

source "amazon-ebs" "al2023" {
  region                    = var.aws_region
  instance_type             = var.instance_type
  ssh_username              = "ec2-user"
  ami_name                  = "${var.ami_name_prefix}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  vpc_id                    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id                 = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address = true
  temporary_security_group_source_cidrs = ["0.0.0.0/0"]

  tags = {
    Project     = "penpot-cloud-image-aws"
    ManagedBy   = "packer"
    Repository  = "penpot-cloud-images"
  }

  run_tags = {
    Name        = "penpot-cloud-image-aws-builder"
    Project     = "penpot-cloud-image-aws"
    ManagedBy   = "packer"
    Repository  = "penpot-cloud-images"
  }

  snapshot_tags = {
    Project     = "penpot-cloud-image-aws"
    ManagedBy   = "packer"
    Repository  = "penpot-cloud-images"
  }

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["137112412989"]
  }
}

build {
  name    = "penpot-cloud-image-aws"
  sources = ["source.amazon-ebs.al2023"]

  provisioner "file" {
    source      = "shared/templates/penpot-docker-compose.yaml"
    destination = "/tmp/penpot-docker-compose.yaml"
  }

  provisioner "file" {
    source      = "shared/templates/penpot.env.example"
    destination = "/tmp/penpot.env.example"
  }

  provisioner "file" {
    source      = "shared/templates/penpot-nginx.conf"
    destination = "/tmp/penpot-nginx.conf"
  }

  provisioner "file" {
    source      = "shared/scripts/configure-penpot.sh"
    destination = "/tmp/configure-penpot.sh"
  }

  provisioner "file" {
    source      = "shared/systemd/penpot-compose.service"
    destination = "/tmp/penpot-compose.service"
  }

  provisioner "shell" {
    script = "shared/scripts/install-docker.sh"
  }

  provisioner "shell" {
    script = "shared/scripts/install-penpot-host.sh"
  }
}
