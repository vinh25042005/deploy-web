data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "rancher" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.sg_ids
  key_name               = var.key_name
  associate_public_ip_address = true
  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }
  user_data = base64encode(templatefile("${path.module}/scripts/install-rancher.sh", {
    rancher_version = var.rancher_version
  }))
  tags = { Name = "${var.project_name}-rancher" }
}
