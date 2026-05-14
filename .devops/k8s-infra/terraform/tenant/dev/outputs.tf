output "master_public_ip" {
  description = "Public IP of K8s master node"
  value       = module.master.public_ip
}

output "master_private_ip" {
  description = "Private IP of K8s master node"
  value       = module.master.private_ip
}

output "worker1_public_ip" {
  description = "Public IP of K8s worker-1 node"
  value       = module.worker_1.public_ip
}

output "worker1_private_ip" {
  description = "Private IP of K8s worker-1 node"
  value       = module.worker_1.private_ip
}

output "private_key_path" {
  description = "Path to SSH private key"
  value       = pathexpand("~/.ssh/${var.key_name}.pem")
}

output "application_url" {
  description = "URL to access the Todo application"
  value       = "http://${module.worker_1.public_ip}:30001"
}

output "ssh_master_command" {
  description = "SSH command to connect to master node"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.master.public_ip}"
}

output "ssh_worker_command" {
  description = "SSH command to connect to worker node"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.worker_1.public_ip}"
}
