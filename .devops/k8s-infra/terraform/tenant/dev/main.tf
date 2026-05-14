module "master" {
  source             = "../../modules/ec2"
  name               = "k8s-master-node"
  ami                = "ami-0c398cb65a93047f2"  # us-east-1 Ubuntu 22.04 LTS
  instance_type      = "t3a.medium"
  subnet_id          = "YOUR_SUBNET_ID_1"  # us-east-1c
  vpc_id             = "YOUR_VPC_ID"
  key_name           = aws_key_pair.generated_key.key_name
  security_group_ids = aws_security_group.ec2_sg.id
  user_data          = file("${path.module}/scripts/master_user_data.sh")

  NodeName    = "kube-master"
  Project     = "pipetask-k8s"
  NodeRole    = "master"
  NodeId      = "1"
  environment = "dev"
}

module "worker_1" {
  source             = "../../modules/ec2"
  name               = "k8s-worker1-node"
  ami                = "ami-0c398cb65a93047f2"  # us-east-1 Ubuntu 22.04 LTS
  instance_type      = "t3a.medium"
  subnet_id          = "YOUR_SUBNET_ID_2"  # us-east-1d
  vpc_id             = "YOUR_VPC_ID"
  key_name           = aws_key_pair.generated_key.key_name
  security_group_ids = aws_security_group.ec2_sg.id
  user_data          = file("${path.module}/scripts/worker1_user_data.sh")
  depends_on         = [module.master]

  NodeName    = "worker-1"
  Project     = "pipetask-k8s"
  NodeRole    = "worker"
  NodeId      = "1"
  environment = "dev"
}

# -------------------------------
# Security Group for K8s Cluster
# -------------------------------
resource "aws_security_group" "ec2_sg" {
  vpc_id = "YOUR_VPC_ID"
  name   = "K8S-CLUSTER-sg"

  tags = {
    Name = "K8S-CLUSTER-sg"
  }

  # ---- Master API Server ----
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ---- etcd (Master <-> Master) ----
  ingress {
    description = "etcd server client API"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  # ---- Kubelet API ----
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  # ---- kube-scheduler ----
  ingress {
    description = "kube-scheduler"
    from_port   = 10251
    to_port     = 10251
    protocol    = "tcp"
    self        = true
  }

  # ---- kube-controller-manager ----
  ingress {
    description = "kube-controller-manager"
    from_port   = 10252
    to_port     = 10252
    protocol    = "tcp"
    self        = true
  }

  # ---- kube-proxy health check ----
  ingress {
    description = "kube-proxy health check"
    from_port   = 10256
    to_port     = 10256
    protocol    = "tcp"
    self        = true
  }

  # ---- NodePort Service Range ----
  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ---- Allow SSH ----
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ---- Flannel VXLAN UDP ports ----
  ingress {
    description = "Flannel VXLAN UDP port"
    from_port   = 8285
    to_port     = 8285
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "Flannel VXLAN alternative port UDP"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
  }

  # ---- Application Ports ----
  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node.js Backend"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "React Frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ---- Outbound traffic ----
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------------
# SSH Key Pair
# -------------------------------
variable "key_name" {
  description = "AWS Key Pair Name"
  type        = string
  default     = "devops-keypem-ansible"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = pathexpand("~/.ssh/${var.key_name}.pem")
  file_permission = "0400"
}

# -------------------------------
# Ansible Inventory Generation
# -------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/ansible/inventory.ini", {
    MASTER_PUBLIC_IP  = module.master.public_ip
    WORKER1_PUBLIC_IP = module.worker_1.public_ip
  })
  filename = "${path.module}/ansible/inventory.generated.ini"
}

# -------------------------------
# Terraform sonrası Ansible çalıştır
# (Jenkins pipeline'da çalışacak, local test için devre dışı)
# -------------------------------
# resource "null_resource" "join_workers" {
#   depends_on = [
#     module.master,
#     module.worker_1,
#     local_file.ansible_inventory
#   ]
#
#   provisioner "local-exec" {
#     command = "ansible-playbook -i ${path.module}/ansible/inventory.generated.ini ${path.module}/ansible/join-workers.yml"
#   }
# }
