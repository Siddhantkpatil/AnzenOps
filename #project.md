### Tools and stack! {yaml *** is Very Important!}
#  Iac and Cloud 
\_ Terrafoem
\_ ANsible 
\_ Aws... 

#  Container and Orchestration
\_ Docker images
\_ Eks 

# SAST & DAST
\_  Sonarcube
\_   Owasp Zap

# Monitoring!!













#  CI/CD
\_ Argo Cd 
\_ GitHub Actions 

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


# 