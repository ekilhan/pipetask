# ⚙️ PipeTask

> Cloud-native task management app — deployed automatically to Kubernetes via Jenkins CI/CD pipeline.

![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-D24939?logo=jenkins&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Cluster-326CE5?logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?logo=ansible&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Containers-2496ED?logo=docker&logoColor=white)
![AWS ECR](https://img.shields.io/badge/AWS-ECR-FF9900?logo=amazonaws&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?logo=grafana&logoColor=white)
![React](https://img.shields.io/badge/React-Frontend-61DAFB?logo=react&logoColor=black)
![Node.js](https://img.shields.io/badge/Node.js-Backend-339933?logo=node.js&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-4169E1?logo=postgresql&logoColor=white)

---

## 📌 Overview

PipeTask is a three-tier web application (React + Node.js + PostgreSQL) that serves as the foundation for a full end-to-end CI/CD and infrastructure automation showcase.

The goal of this project was not the application itself, but everything underneath it:
- Provisioning a Kubernetes cluster from scratch using Terraform and Ansible
- Building and pushing Docker images to ECR automatically
- Deploying the app to Kubernetes via an Ansible playbook triggered by Jenkins
- Monitoring the cluster with Prometheus and Grafana

One `git push` kicks off the entire pipeline — infrastructure creation, image build, ECR push, K8s deployment.

---

## 🏗️ Architecture

```
GitHub Repository (pipetask)
        │
        │  Webhook (push event)
        ▼
Jenkins Server (Amazon Linux 2023 - EC2)
        │
        │  Jenkins Pipeline
        │  ├── Terraform  → Create K8s Cluster (Master + Worker EC2)
        │  ├── Docker     → Build Images (React / Node.js / PostgreSQL)
        │  ├── ECR        → Push Images
        │  └── Ansible    → Deploy to Kubernetes
        ▼
Kubernetes Cluster (2 Nodes)
        ├── Master Node (t3a.medium)  →  kubeadm, kubectl, Flannel CNI
        └── Worker Node (t3a.medium)  →  React Pod, Node.js Pod, PostgreSQL Pod
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| CI/CD | Jenkins (Declarative Pipeline) |
| Infrastructure | Terraform |
| Configuration & Deployment | Ansible |
| Container Runtime | Docker |
| Container Registry | Amazon ECR |
| Orchestration | Kubernetes (kubeadm, Flannel CNI) |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |
| Frontend | React |
| Backend | Node.js + Express |
| Database | PostgreSQL |
| Cloud | AWS EC2 |

---

## 🔄 Pipeline Stages

| Stage | Description |
|---|---|
| Create K8s Infrastructure | Terraform provisions master + worker EC2 instances, security groups, IAM roles |
| Create ECR Repo | Creates ECR repository if it doesn't exist |
| Build Docker Images | Builds React, Node.js, PostgreSQL images |
| Push Images to ECR | Authenticates and pushes all three images |
| Wait for K8s Cluster | Waits for EC2 status checks + 120s K8s init time |
| Verify K8s Cluster | Runs `kubectl get nodes` via Ansible to confirm cluster health |
| Join Workers | Ansible playbook runs `kubeadm join` on worker node |
| Deploy to Kubernetes | Ansible deploys all K8s manifests (Deployments, Services, Secrets) |
| Get Application URL | Prints the live application URL from Terraform output |
| Destroy Infrastructure | Manual approval gate — tears down everything after use |

---

## 📊 Monitoring

Monitoring is set up with the `kube-prometheus-stack` Helm chart, which includes Prometheus, Grafana, AlertManager, Node Exporter, and kube-state-metrics.

Grafana is exposed via NodePort and includes pre-built dashboards for:
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods) — filtered to `pipetask`
- Node Exporter / Nodes — CPU, memory, disk metrics for the worker node

---

## 🚀 Getting Started

### Prerequisites

- AWS account with EC2 and ECR permissions
- Jenkins server with Docker, Terraform, Ansible, AWS CLI installed
- GitHub Personal Access Token (for private repo access in Jenkins)

### Jenkins Credentials Required

| ID | Type | Description |
|---|---|---|
| `github-credentials` | Username + Password | GitHub PAT for repo access |
| `db-password` | Secret text | PostgreSQL password |

### Configuration

Before running the pipeline, update the following in `.devops/k8s-infra/terraform/tenant/dev/main.tf`:

```hcl
subnet_id = "YOUR_SUBNET_ID_1"   # Master node subnet
subnet_id = "YOUR_SUBNET_ID_2"   # Worker node subnet
vpc_id    = "YOUR_VPC_ID"
```

These should match the VPC where your Jenkins server is running.

### Running the Pipeline

1. Create a Jenkins Pipeline job pointing to this repo
2. Set `Script Path` to `Jenkinsfile`
3. Click **Build Now**
4. After successful deployment, the application URL is printed in the console output
5. When done, approve the **Destroy Infrastructure** stage to clean up all AWS resources

---

## 📁 Project Structure

```
pipetask/
├── Jenkinsfile
├── node-env-template
├── react-env-template
├── react/
│   ├── dockerfile-react
│   └── client/
├── nodejs/
│   ├── dockerfile-nodejs
│   └── server/
├── postgresql/
│   ├── dockerfile-postgresql
│   └── init.sql
├── create-jenkins-server-tf/
└── .devops/
    ├── k8s-infra/
    │   └── terraform/
    │       ├── modules/ec2/
    │       └── tenant/dev/
    │           ├── main.tf
    │           ├── outputs.tf
    │           └── ansible/
    ├── ansible/
    │   ├── ansible.cfg
    │   ├── playbooks/deploy.yml
    │   └── roles/kubernetes/
    └── k8s/
        ├── namespace.yaml
        ├── postgresql-deployment.yaml
        ├── nodejs-deployment.yaml
        └── react-deployment.yaml
```

---

## ⚠️ Notes

- The Kubernetes cluster is created fresh on every pipeline run and destroyed at the end — this is by design for cost efficiency
- Prometheus + Grafana are installed manually via Helm on the master node after deployment (not part of the pipeline)
- Worker node IP is dynamic; the React `.env` is generated at build time via `envsubst` using Terraform outputs
