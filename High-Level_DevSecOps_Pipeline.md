# High-Level DevSecOps Pipeline

---

## 1. Trigger

**Purpose:** Automatically start the pipeline when code is pushed or a Pull Request (PR) is created.

**Tools:**

- GitHub Actions
- GitLab CI/CD
- Jenkins
- AWS CodePipeline

---

## 2. Build & Unit Testing

**Purpose:** Build the application and verify functionality through automated tests.

**Tools:**

- Pytest (Python)
- Jest (JavaScript)
- Maven / Gradle (Java)
- GitHub Actions
- AWS CodeBuild

---

## 3. SAST (Static Application Security Testing)

**Purpose:** Identify security vulnerabilities in source code before deployment.

**Tools:**

- SonarQube
- Semgrep
- CodeQL
- Bandit
- Checkmarx
- Veracode

---

## 4. SCA (Software Composition Analysis)

**Purpose:** Detect vulnerabilities in third-party libraries and dependencies.

**Tools:**

- OWASP Dependency-Check
- npm audit
- pip-audit
- Snyk
- Dependabot
- JFrog Xray

---

## 5. Secrets Scanning

**Purpose:** Detect exposed API keys, passwords, and tokens in source code and Git history.

**Tools:**

- Gitleaks
- TruffleHog
- GitGuardian

---

## 6. Build & Push Container

**Purpose:** Package the application into a Docker image and store it in a registry.

**Tools:**

- Docker
- Amazon ECR
- Docker Hub
- GitHub Container Registry (GHCR)

---

## 7. Container Image Scanning

**Purpose:** Identify vulnerabilities inside container images.

**Tools:**

- Trivy
- Amazon Inspector
- Clair
- Anchore
- Prisma Cloud

---

## 8. IaC Scanning (Terraform & Ansible)

**Purpose:** Detect security misconfigurations in all infrastructure definitions — Terraform configs, Ansible playbooks, Kubernetes manifests, and Helm charts — before any infrastructure is provisioned.

**Tools:**

- Checkov (Terraform, Ansible, Kubernetes, CloudFormation)
- tfsec (Terraform-specific)
- Ansible-lint (Ansible playbook linting)
- kube-score / kube-linter (Kubernetes)
- KICS (Keeping Infrastructure as Code Secure)

---

## 9. Infrastructure Provisioning (Terraform)

**Purpose:** Provision and manage all cloud infrastructure — VPCs, subnets, security groups, EC2, ECS/EKS clusters, RDS, S3 — using Terraform in a repeatable, version-controlled, and auditable manner.

**Tools:**

- Terraform (core IaC tool)
- Terraform Cloud / Terraform Enterprise
- AWS Provider / Azure Provider / GCP Provider
- Terragrunt (Terraform wrapper for DRY configs)
- tfstate stored in S3 + DynamoDB (remote state locking)

---

## 10. Configuration Management (Ansible)

**Purpose:** Configure provisioned servers and deploy application components — install packages, apply OS hardening, manage users, configure services — using Ansible playbooks.

**Tools:**

- Ansible Core
- Ansible Playbooks & Roles
- Ansible Galaxy (community roles)
- Ansible Vault (encrypted secrets)
- AWX / Ansible Automation Platform (enterprise UI)

---

## 11. Deploy to Staging

**Purpose:** Deploy the application to a staging environment (provisioned by Terraform, configured by Ansible) for dynamic testing.

**Tools:**

- Amazon ECS / Amazon EKS
- EC2
- Docker Compose
- Kubernetes
- Helm (Kubernetes package manager)

---

## 12. DAST (Dynamic Application Security Testing)

**Purpose:** Test the running application for security vulnerabilities.

**Tools:**

- OWASP ZAP
- Burp Suite Enterprise
- Invicti
- Acunetix
- StackHawk

---

## 13. Security Gates & Policy Enforcement

**Purpose:** Block deployment if critical vulnerabilities are found across any stage.

**Tools:**

- GitHub Actions Rules
- Jenkins Gates
- Open Policy Agent (OPA)
- Conftest

---

## 14. Deploy to Production

**Purpose:** Deploy the application to production infrastructure (managed by Terraform) after all security checks pass.

**Tools:**

- AWS CodeDeploy
- GitHub Actions
- AWS ECS / AWS EKS
- Kubernetes
- Helm

---

## 15. Dashboard & Vulnerability Management

**Purpose:** Centralize and monitor security findings across all pipeline stages.

**Tools:**

- GitHub Security Tab
- DefectDojo
- AWS Security Hub
- Snyk Dashboard
- Veracode Dashboard

---

## 16. Scheduled Security Scans

**Purpose:** Perform periodic deep security assessments including infrastructure drift detection.

**Tools:**

- OWASP ZAP
- Trivy
- Amazon Inspector
- Snyk
- Terraform Plan (drift detection)
- GitHub Actions Scheduled Workflows

---

# Complete DevSecOps Workflow

```
Git Push / Pull Request
          |
  Build & Unit Tests
          |
       SAST Scan
          |
        SCA Scan
          |
    Secrets Scan
          |
  Build Docker Image
          |
 Container Image Scan
          |
  IaC Scan (Terraform + Ansible)
          |
  Infrastructure Provisioning (Terraform)
          |
  Configuration Management (Ansible)
          |
   Deploy to Staging
          |
       DAST Scan
          |
   Security Gates
          |
  Deploy to Production
          |
  Dashboard & Monitoring
          |
  Scheduled Security Scans
```

---

# Terraform & Ansible — Role Summary

| Tool            | Category                 | Role in Pipeline                                      |
| --------------- | ------------------------ | ----------------------------------------------------- |
| Terraform       | Infrastructure as Code   | Provision cloud resources (VPC, EC2, EKS, RDS, S3)    |
| Terraform Cloud | Remote State & Runs      | Centralized state management and plan/apply execution |
| Terragrunt      | Terraform Wrapper        | DRY Terraform configs across environments             |
| tfsec / Checkov | IaC Security Scanning    | Scan `.tf` files for misconfigurations (Stage 8)      |
| Ansible Core    | Configuration Management | Configure servers, harden OS, deploy app components   |
| Ansible Vault   | Secrets Encryption       | Encrypt sensitive variables in playbooks              |
| Ansible-lint    | Playbook Linting         | Lint playbooks for best practices (Stage 8)           |
| AWX             | Ansible UI               | Centralized job execution and audit logging           |
