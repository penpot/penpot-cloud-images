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

variable "project_tag" {
  type    = string
  default = "penpot-cloud-image-aws"
}

variable "release_version" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type    = string
  default = ""
}

locals {
  ami_version_suffix = var.release_version != "" ? var.release_version : formatdate("YYYYMMDDhhmmss", timestamp())
  ami_name_value     = "${var.ami_name_prefix}-${local.ami_version_suffix}"
}

source "amazon-ebs" "al2023" {
  region                                = var.aws_region
  instance_type                         = var.instance_type
  ssh_username                          = "ec2-user"
  ami_name                              = local.ami_name_value
  vpc_id                                = var.vpc_id != "" ? var.vpc_id : null
  subnet_id                             = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address           = true
  temporary_security_group_source_cidrs = ["0.0.0.0/0"]

  tags = {
    Name       = local.ami_name_value
    Project    = var.project_tag
    ManagedBy  = "packer"
    Repository = "penpot-cloud-images"
    Version    = var.release_version != "" ? var.release_version : "unversioned"
  }

  run_tags = {
    Name       = "penpot-cloud-image-aws-builder"
    Project    = var.project_tag
    ManagedBy  = "packer"
    Repository = "penpot-cloud-images"
  }

  snapshot_tags = {
    Name       = local.ami_name_value
    Project    = var.project_tag
    ManagedBy  = "packer"
    Repository = "penpot-cloud-images"
    Version    = var.release_version != "" ? var.release_version : "unversioned"
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
