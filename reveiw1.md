# Project Title:       
### Ageisflow / VarmanSetu :End-to-End DevSecOps CI/CD Pipeline with GitOps and Observability.

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
1) Ias: Ansible , Terraform
2) Continuous Integration
3) Continuous Deployment/Delivery
4) SAST
5) DAST
6) Image & Scannig : Docker and Trivy
7) Orchestration: EKS
8) Monitoring: 



# Execution Flow:



