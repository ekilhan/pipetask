resource "aws_instance" "this" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = var.user_data != null ? var.user_data : null
  iam_instance_profile        = aws_iam_instance_profile.this.name
  vpc_security_group_ids      = [var.security_group_ids]

  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.name}-ec2"
    name        = var.NodeName
    Project     = var.Project
    Role        = var.NodeRole
    Id          = var.NodeId
    environment = var.environment
  }
}

resource "aws_iam_role" "ec2_instance_role" {
  name = "${var.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_attach_policy" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2_instance_role.name
}
