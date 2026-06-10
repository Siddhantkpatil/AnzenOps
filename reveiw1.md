# Project Title:       
###  AnzenOps:End-to-End DevSecOps CI/CD Pipeline with GitOps and Observability.

# Objective:
{An objective is a specific, measurable result that you plan to achieve within a set timeframe. It acts as a clear target that guides your actions and defines what success looks like }
* Shift Security Left: Identify code vulnerabilities and leaked secrets early during the GitHub Actions build phase before deployment.
* Automate GitOps Deployments: Eliminate manual infrastructure updates by using ArgoCD to synchronize your Kubernetes cluster automatically with your repository.
* Continuous Runtime Protection: Validate active application security using OWASP ZAP DAST while monitoring system threats through Wazuh.
* Full-Stack Observability: Gain real-time visibility into infrastructure health and application logs using Grafana, Prometheus, and Kibana.



# Workflow:

                                                    ┌─────────────────┐
                                                    │   Developer     │
                                                    └────────┬────────┘
                                                             │
                                                        _____|
                                                        ▼
                                                    ┌─────────────────┐
                                                    │ GitHub Repo     │
                                                    └────────┬────────┘
                                                             │
                                                        _____|
                                                        ▼
                                                ┌─────────────────────────┐
                                                │ GitHub Actions CI/CD    │
                                                └────────┬────────────────┘
                                                         │
                                        ┌────────────────┼────────────────┐
                                        ▼                ▼                ▼
                                SonarQube         Trivy Scan       Secrets Scan
                                    (SAST)         (Image Scan)       (Gitleaks)
                                        │                │                │
                                        └────────────────┴────────────────┘
                                                         │
                                                         ▼
                                                Build Docker Image
                                                         │
                                                         ▼
                                                    Push to ECR
                                                         │
                                                         ▼
                                                      ArgoCD
                                                         │
                                                         ▼
                                                Kubernetes Cluster
                                            ┌──────────┴──────────┐
                                            ▼                     ▼
                                    Application Pods       OWASP ZAP
                                                                │
                                                                ▼
                                                            DAST Report 
                                                       |                        
                                            ┌──────────┴──────────┐
                                            ▼                     ▼
                                        Prometheus            FluentBit
                                            │                     │
                                            ▼                     ▼
                                        Grafana               Wazuh
                                                                │
                                                                ▼
                                                         Elasticsearch
                                                                │
                                                                ▼
                                                             Kibana


# Tools and Techology used:
1) Iac: Ansible ,Terraform
2) Continuous Integration: GitHub Actions
3) Continuous Deployment/Delivery: AgroCD
4) SAST: SonarCube
5) DAST: OWASP Zap
6) Image & Scanning: Docker and Trivy
7) Orchestration: EKS
8) Health & Performance Monitoring: Prometheus + Grafana 
9) Security Monitoring / SIEM: Wazuh + ELK 

# Infrastructure
AWS Account
│
└── VPC (10.0.0.0/16)
    │
    ├── Public Subnet (10.0.1.0/24)
    │   │
    │   ├── Bastion Host (EC2)
    │   │    ├─ SSH Access
    │   │    └─ Ansible Control Node
    │   │
    │   └── NAT Gateway
    │
    ├── Private Subnet A (10.0.2.0/24)
    │   │
    │   ├── Kubernetes Master Node
    │   │
    │   └── SonarQube Server
    │
    ├── Private Subnet B (10.0.3.0/24)
    │   │
    │   ├── Kubernetes Worker Node 1
    │   │
    │   └── Kubernetes Worker Node 2
    │
    └── Private Subnet C (10.0.4.0/24)
        │
        ├── Monitoring Server
        │    ├─ Prometheus
        │    ├─ Grafana
        │    └─ AlertManager
        │
        └── SIEM Server
             ├─ Wazuh
             ├─ Elasticsearch
             └─ Kibana     

# Project Execution Flow:
1) Build the Application to deploy



