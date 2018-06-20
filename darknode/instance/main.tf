
variable "region" {}
variable "avz" {}
variable "ami" {}
variable "id" {}
variable "config" {}
variable "ec2_instance_type" {}
variable "ssh_public_key" {}
variable "ssh_private_key_location" {}
variable "access_key" {}
variable "secret_key" {}
variable "is_bootstrap" {}
variable "port" {}

variable "bootstraps" {
  default = []
}

provider "aws" {
  alias      = "falcon0"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_security_group" "falcon0" {
  provider    = "aws.falcon0"
  name        = "falcon-sg-${var.id}"
  description = "Allow inbound SSH and Republic Protocol traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "falcon0" {
  provider   = "aws.falcon0"
  key_name   = "falcon-kp-${var.id}"
  public_key = "${var.ssh_public_key}"
}

output "multiaddress" {
  value       = "/ip4/${aws_instance.falcon0.public_ip}/tcp/18514/republic/${var.id}"
}

resource "aws_instance" "falcon0" {
  provider        = "aws.falcon0"
  ami             = "${var.ami}"
  instance_type   = "${var.ec2_instance_type}"
  key_name        = "${aws_key_pair.falcon0.key_name}"
  security_groups = ["${aws_security_group.falcon0.name}"]

  provisioner "file" {
    source      = "${var.config}"
    destination = "/home/ubuntu/darknode-config.json"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("${var.ssh_private_key_location}")}"
    }
  }

  provisioner "file" {
    source      = "./provisions"
    destination = "/home/ubuntu/provisions"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("${var.ssh_private_key_location}")}"
    }
  }

  provisioner "remote-exec" {
    script = "./scripts/onCreate.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("${var.ssh_private_key_location}")}"
    }
  }

  provisioner "local-exec" {
      command = "echo /ip4/${aws_instance.falcon0.public_ip}/tcp/${var.port}/republic/${var.id} >> multiAddress.out"
  }
}
