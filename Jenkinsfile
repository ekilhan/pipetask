pipeline {
    agent any

    tools {
        terraform 'terraform'
    }

    environment {
        PATH = sh(script: "echo \$PATH:/usr/local/bin", returnStdout: true).trim()
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT_ID = sh(script: 'export PATH="\$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        APP_REPO_NAME = "project-repo/pipetask"
        TERRAFORM_DIR = ".devops/k8s-infra/terraform/tenant/dev"
        ANSIBLE_INVENTORY = "${WORKSPACE}/${TERRAFORM_DIR}/ansible/inventory.generated.ini"
        ANSIBLE_PRIVATE_KEY_FILE = "~/.ssh/devops-keypem-ansible.pem"
        ANSIBLE_HOST_KEY_CHECKING = "False"
        DB_PASSWORD = credentials('db-password')
    }

    stages {
        stage('Create K8s Infrastructure') {
            steps {
                echo 'Creating Kubernetes Cluster Infrastructure with Terraform'
                dir("${TERRAFORM_DIR}") {
                    sh 'terraform init'
                    sh 'terraform apply --auto-approve -no-color'
                }
            }
        }

        stage('Create ECR Repo') {
            steps {
                echo 'Creating ECR Repository for Docker Images'
                sh '''
                aws ecr describe-repositories --region ${AWS_REGION} --repository-name ${APP_REPO_NAME} || \
                aws ecr create-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --image-scanning-configuration scanOnPush=false \
                  --image-tag-mutability MUTABLE \
                  --region ${AWS_REGION}
                '''
            }
        }

        stage('Build Docker Images') {
            steps {
                echo 'Building Docker Images for Todo App'
                script {
                    env.MASTER_IP = sh(script: "cd ${TERRAFORM_DIR} && terraform output -raw master_public_ip", returnStdout: true).trim()
                    env.WORKER_IP = sh(script: "cd ${TERRAFORM_DIR} && terraform output -raw worker1_public_ip", returnStdout: true).trim()
                    env.DB_HOST = "postgresql"
                    env.DB_NAME = "tododb"
                }

                echo "Master IP: ${MASTER_IP}"
                echo "Worker IP: ${WORKER_IP}"
                echo "DB Host: ${DB_HOST}"

                sh 'envsubst < node-env-template > ./nodejs/server/.env'
                sh 'cat ./nodejs/server/.env'
                sh 'envsubst < react-env-template > ./react/client/.env'
                sh 'cat ./react/client/.env'

                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:postgre" -f ./postgresql/dockerfile-postgresql .'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:nodejs" -f ./nodejs/dockerfile-nodejs .'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:react" -f ./react/dockerfile-react .'
                sh 'docker image ls'
            }
        }

        stage('Push Images to ECR') {
            steps {
                echo 'Pushing Docker Images to ECR Repository'
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:postgre"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:nodejs"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:react"'
            }
        }

        stage('Wait for K8s Cluster') {
            steps {
                echo 'Waiting for Kubernetes Cluster to be Ready'
                script {
                    def masterId = sh(
                        script: "cd ${TERRAFORM_DIR} && terraform output -raw master_public_ip | xargs -I {} aws ec2 describe-instances --region ${AWS_REGION} --filters Name=ip-address,Values={} Name=instance-state-name,Values=running --query 'Reservations[*].Instances[*].InstanceId' --output text",
                        returnStdout: true
                    ).trim()

                    echo "Master Instance ID: ${masterId}"
                    sh "aws ec2 wait instance-status-ok --region ${AWS_REGION} --instance-ids ${masterId}"
                    echo 'Waiting additional 120 seconds for K8s cluster initialization...'
                    sleep(120)
                }
            }
        }

        stage('Verify K8s Cluster') {
            steps {
                script {
                        echo 'Verifying Kubernetes Cluster Status'
                        sh '''
                        export ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY}"
                        export ANSIBLE_PRIVATE_KEY_FILE="${ANSIBLE_PRIVATE_KEY_FILE}"
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        ansible masters -m shell -a "kubectl get nodes" --become-user ubuntu
                        '''
                }
            }
        }

        stage('Join Workers to Cluster') {
            steps {
                echo 'Joining worker nodes to Kubernetes cluster'
                sh '''
                ansible-playbook -i "${ANSIBLE_INVENTORY}" \
                ${TERRAFORM_DIR}/ansible/join-workers.yml \
                --private-key ${ANSIBLE_PRIVATE_KEY_FILE} \
                -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
                '''
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                        echo 'Deploying Todo App to Kubernetes Cluster'
                        sh '''
                        export ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY}"
                        export ANSIBLE_PRIVATE_KEY_FILE="${ANSIBLE_PRIVATE_KEY_FILE}"
                        export ANSIBLE_HOST_KEY_CHECKING=False
                        export ANSIBLE_CONFIG="${WORKSPACE}/.devops/ansible/ansible.cfg"

                        ansible-playbook -i "${ANSIBLE_INVENTORY}" \
                          .devops/ansible/playbooks/deploy.yml \
                          -e "ecr_registry=${ECR_REGISTRY}" \
                          -e "aws_region=${AWS_REGION}" \
                          -e "db_password=${DB_PASSWORD}" \
                          -e "master_public_ip=${MASTER_IP}" \
                          -e "worker_public_ip=${WORKER_IP}"
                        '''
                } 
            }
        }

        stage('Get Application URL') {
            steps {
                script {
                    def appUrl = sh(
                        script: "cd ${TERRAFORM_DIR} && terraform output -raw application_url",
                        returnStdout: true
                    ).trim()

                    echo "=========================================="
                    echo "Todo Application is Ready!"
                    echo "Application URL: ${appUrl}"
                    echo "=========================================="
                }
            }
        }

        stage('Destroy Infrastructure') {
            steps {
                timeout(time: 5, unit: 'DAYS') {
                    input message: 'Approve Infrastructure Termination'
                }

                echo 'Destroying Kubernetes Infrastructure'
                sh """
                docker image prune -af

                cd ${TERRAFORM_DIR}
                terraform destroy --auto-approve -no-color

                aws ecr delete-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --region ${AWS_REGION} \
                  --force
                """
            }
        }
    }

    post {
        always {
            echo 'Cleaning up Docker images'
            sh 'docker image prune -af || true'

        }

        failure {
            echo 'Pipeline Failed - Cleaning up resources'
            sh """
                    aws ecr delete-repository \
                      --repository-name ${APP_REPO_NAME} \
                      --region ${AWS_REGION} \
                      --force || true

                    cd ${TERRAFORM_DIR}
                    terraform destroy --auto-approve -no-color || true
            """
        }

        success {
            echo 'Pipeline Completed Successfully!'
        }
    }
}
