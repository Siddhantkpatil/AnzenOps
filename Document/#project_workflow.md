# Tools and stack! {yaml *** is Very Important!}
##  Iac and Cloud 
\_ Terrafoem
\_ ANsible 
\_ Aws... 

## Container and Orchestration
\_ Docker images
\_ Eks 

## SAST & DAST
\_  Sonarcube
\_   Owasp Zap

## Monitoring!!
┌─────────────────────────┐     ┌────────────────┐     ┌───────────────┐     ┌────────────┐
│      LOG SOURCES        │ ──> │ DATA COLLECTOR │ ──> │ ELK STORAGE & │ ──> │ ANALYTICS  │
│  (Your Infrastructure)  │     │   (Logstash)   │     │    INDEXING   │     │  (Kibana)  │
└─────────────────────────┘     └────────────────┘     └───────────────┘     └────────────┘
  • AWS VPC Flow Logs             • Normalizes text      • Elasticsearch       • Security 
  • AWS CloudTrail                • Filters noise          database              Dashboards
  • EKS Pod Logs (`Filebeat`)     • Adds Geo-IP tags                           • Threat 
  • EC2 Host Logs (`Auditbeat`)                                                  Hunting



##  CI/CD
\_ Argo Cd 
\_ GitHub Actions 
-----------------



# WORKFLOW..........

                                                        [ Developer Code Push ]
                                                                │
                                                                ▼
                                    ┌────────────────────────────────────────────────────────┐
                                    │ 1. COMMIT STAGE (GitHub )                              │
                                    │   ├── Pre-commit: GitLeaks (Secret Scanning)           │
                                    │   └── SCA: Trivy / Snyk (Dependency Check)             │
                                    └────────┬───────────────────────────────────────────────┘
                                                                │
                                                                ▼
                                    ┌────────────────────────────────────────────────────────┐
                                    │ 2. BUILD & SAST STAGE                                  │
                                    │   ├── SAST: SonarQube / Semgrep (Static Code Review)   │
                                    │   └── Container Scan: Trivy (Docker Base Image Check)  │
                                    └────────┬───────────────────────────────────────────────┘
                                                                │ (Passes Checks) ──> Push to AWS ECR
                                                                ▼
                                    ┌────────────────────────────────────────────────────────┐
                                    │ 3. INFRASTRUCTURE AS CODE (IaC) STAGE {it depends}     │
                                    │   ├── Terraform: Deploys VPC & EKS Cluster             │
                                    │   ├── IaC Scan: tfsec / Chekov (Validates TF files)    | 
                                    │   └── Ansible: Configures EC2 Nodes / OS Hardening     │
                                    └────────┬───────────────────────────────────────────────┘
                                                                │
                                                                ▼
                                    ┌────────────────────────────────────────────────────────┐
                                    │ 4. DEPLOY & DAST STAGE (Staging / QA)                  │
                                    │   ├── Helm / ArgoCD: Deploys App to EKS                │
                                    │   └── DAST: OWASP ZAP (Scans Live App API/Endpoints)   │
                                    └────────┬───────────────────────────────────────────────┘
                                                                │ (Passes DAST)
                                                                ▼
                                    ┌────────────────────────────────────────────────────────┐
                                    │ 5. PRODUCTION & CONTINUOUS MONITORING                  │
                                    │   ├── EKS Runtime: Prometheus + Grafana (Metrics)      │
                                    │   └── Security Auditing: AWS CloudWatch + GuardDuty    │
                                    └────────────────────────────────────────────────────────┘


# flowchart 2....
                                  ┌──────────────────────────┐
                                  │   LOCAL BASE MACHINE     │
                                  │  (Runs Initial Terraform │
                                  │   to provision AWS Infra)│
                                  └────────────┬─────────────┘
                                               │
                                               ▼
     ┌──────────────────────────────────────────────────────────────────────────────────┐
     │                                AWS CLOUD  (VPC)                                  │
     │                                                                                  │
     │  ┌───────────────────────────────┐     ┌──────────────────────────────────────┐  │
     │  │     PUBLIC SUBNETS            │     │          PRIVATE SUBNETS             │  │
     │  │                               │     │                                      │  │
     │  │  ┌─────────────────────────┐  │     │  ┌────────────────────────────────┐  │  │
     │  │  │   Internet Gateway      │  │     │  │  AWS MANAGED OPENSEARCH        │  │  │
     │  │  └────────────┬────────────┘  │     │  │  (SIEM Data Storage Engine)    │  │  │
     │  │               │               │     │  └──────────────▲─────────────────┘  │  │
     │  │               ▼               │     │                 │ Updates            │  │
     │  │  ┌─────────────────────────┐  │     │  ┌──────────────┴─────────────────┐  │  │
     │  │  │   AWS NAT Gateway       │──┼─────┼─►│     EC2 NODE 3 (Wazuh SIEM)    │  │  │
     │  │  └─────────────────────────┘  │     │  └──────────────▲─────────────────┘  │  │
     └──┴───────────────────────────────┴─────┴─────────────────┼────────────────────┴──┘
                                                                │ Streams Security Alerts
                                                                │
┌──────────────────────────────┐              ┌─────────────────┴───────────────────────┐
│     GITHUB CODE REPO         │              │            AWS EKS CLUSTER              │
│                              │              │     (EC2 Node 1 & EC2 Node 2)           │
│  • Holds Code & IaC Scripts  │              │                                         │
│  • Hosts GitHub Actions      │              │  ┌───────────────────────────────────┐  │
└──────────────┬───────────────┘              │  │       APP PODS (Production)       │  │
               │                              │  └───────────────────────────────────┘  │
               │ Triggers Pipeline            │  ┌───────────────────────────────────┐  │
               ▼                              │  │     ARGOCD (GitOps Deployer)      │  │
┌──────────────────────────────┐              │  └──────────────────▲────────────────┘  │
│  GITHUB ACTIONS RUNNER (CI)  │              │                     │ Pulls Manifests   │
│                              │              │  ┌──────────────────┴────────────────┐  │
│  1. Secret Scan: TruffleHog  │              │  │   PROMETHEUS & GRAFANA (Health)   │  │
│  2. SAST Scan: Semgrep       │              │  └───────────────────────────────────┘  │
│  3. Container Build          │              │  ┌───────────────────────────────────┐  │
│  4. Target DAST: Nuclei  ────┼──────────────┼─►│  Wazuh Agent & FluentBit (Logs)   │  │
└──────────────────────────────┘ Attacks Live │  └───────────────────────────────────┘  │
                                 Staging Pod  └─────────────────────────────────────────┘

\_________________
# CHATGPTT \|/

### DevSecOps Flow..
                    ┌─────────────────┐
                    │   Developer     │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ GitHub Repo     │
                    └────────┬────────┘
                             │
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



### infraa -Structure!!
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

###  Monitoring..

> montoring...                                             
 Application Logs                                         
       │
       ▼
   Fluent Bit
       │
       ▼
    Wazuh
       │
       ▼
  Elasticsearch
       │
       ▼
    Kibana



> SEIM
Application Logs
       │
       ▼
Fluent Bit
       │
       ▼
Wazuh
       │
       ▼
Elasticsearch
       │
       ▼
Kibana

1. Prometheus + Grafana (Health & Performance Monitoring)
This stack monitors whether your infrastructure and application are running properly. It collects metrics from EC2 instances, Kubernetes nodes, pods, containers, databases, and microservices. It tracks CPU usage, memory usage, disk space, network traffic, pod status, application response time, request count, error rate, and database performance. If a server's CPU reaches 90%, a Kubernetes pod crashes, or an API becomes slow, Prometheus detects it and Grafana displays it on dashboards and can trigger alerts.

2. Wazuh + ELK (Security Monitoring / SIEM)
This stack monitors security-related activities and logs. It collects logs from EC2 servers, Kubernetes nodes, applications, and operating systems. It watches for failed SSH logins, brute-force attacks, unauthorized access attempts, suspicious user activity, file modifications, privilege escalation, Kubernetes security events, and application security incidents. If someone repeatedly tries to log in, modifies a critical system file, or performs suspicious actions in the cluster, Wazuh detects it and stores the events in Elasticsearch while Kibana provides security dashboards and investigation capabilities.

\__ Simple Difference
Prometheus + Grafana: "Is my system healthy and performing well?"
Wazuh + ELK: "Is someone attacking my system or doing something suspicious?"
\__ So in your project:
Prometheus/Grafana = Infrastructure + Kubernetes + Application Performance Monitoring
Wazuh/ELK          = Security Monitoring + Log Analysis + SIEM

