# Low-Level DevSecOps Pipeline — Detailed Reference

---

## Stage 1 — Trigger

### What Happens

The pipeline is initiated automatically when a developer performs one of the following Git events:

- `git push` to `main`, `develop`, or any protected branch
- Opening a Pull Request (PR) or Merge Request (MR)
- Merging a PR into a target branch
- A scheduled cron-based trigger (for nightly scans)

### Internal Steps

1. The CI/CD platform (GitHub Actions / GitLab CI / Jenkins) listens for webhook events from the Git repository.
2. On event received, the platform evaluates **branch filter rules** — only specific branches trigger the full pipeline.
3. A **pipeline runner** (agent/worker) is allocated.
4. The workspace is initialized — the repository is cloned at the specific commit SHA.
5. Environment variables (secrets, tokens, registry credentials) are injected from the secrets vault.
6. Pipeline stages are queued based on the workflow definition file (`.github/workflows/*.yml` or `Jenkinsfile`).

### Inputs

- Git event (push, PR, schedule)
- Branch name and commit SHA
- Developer identity (author of the commit)

### Outputs

- Triggered pipeline run with a unique Run ID
- Checked-out source code in the runner workspace
- Injected environment variables and secrets

### Failure Conditions

- Webhook misconfiguration — pipeline not triggered
- Runner unavailable or queue timeout
- Invalid secrets reference — pipeline aborts at start

---

## Stage 2 — Build & Unit Testing

### What Happens

The application source code is compiled (if required) and all unit tests are executed to verify that the core logic functions correctly before security scanning begins.

### Internal Steps

**Build Phase:**

1. Dependency installation — fetch all declared packages from the package manager (pip, npm, Maven, Gradle).
2. Compile the source code (mandatory for Java/Go/C++; optional for Python/JS).
3. Generate build artifacts — `.jar`, `.war`, `.exe`, compiled binaries, or bundled JS.
4. Cache dependencies to speed up future runs.

**Unit Testing Phase:**

1. Test runner discovers all test files matching naming conventions (`test_*.py`, `*.test.js`, `*Test.java`).
2. Tests execute in an isolated environment — no network, no external DB.
3. Code coverage is measured.
4. Test results serialized as JUnit XML reports.
5. Pipeline stops here (fail-fast) if any test fails or coverage drops below the threshold.

### Inputs

- Source code from the repository
- Dependency manifest files (`requirements.txt`, `package.json`, `pom.xml`)

### Outputs

- Compiled build artifacts
- Test result report (pass/fail counts, duration)
- Code coverage report

### Key Metrics

| Metric              | Recommended Threshold |
| ------------------- | --------------------- |
| Unit test pass rate | 100%                  |
| Code coverage       | >= 80%                |
| Build time          | < 5 minutes           |

---

## Stage 3 — SAST (Static Application Security Testing)

### What Happens

The source code is analyzed **without executing it** to find security vulnerabilities, insecure coding patterns, and potential weaknesses.

### Internal Steps

1. The SAST tool parses the code into an **Abstract Syntax Tree (AST)**.
2. Predefined rule sets (CWE, OWASP Top 10) are applied against the parsed tree.
3. Taint analysis tracks how untrusted user input flows to sensitive sinks (SQL queries, file writes, command execution).
4. Findings classified by severity: Critical, High, Medium, Low, Informational.
5. Results exported in SARIF format.
6. Pipeline blocked if Critical or High findings exceed the configured threshold.

### What SAST Detects

- SQL Injection (CWE-89)
- Cross-Site Scripting — XSS (CWE-79)
- Command Injection (CWE-78)
- Insecure Deserialization (CWE-502)
- Hardcoded credentials in source (CWE-798)
- Path Traversal (CWE-22)
- Insecure cryptographic functions (CWE-327)
- Use of deprecated or dangerous APIs

### Tool Comparison

| Tool      | Best For                        | License                  |
| --------- | ------------------------------- | ------------------------ |
| SonarQube | Multi-language, CI integration  | Community / Commercial   |
| Semgrep   | Custom rules, fast scans        | Open Source / Commercial |
| CodeQL    | Deep semantic analysis (GitHub) | Free for OSS             |
| Bandit    | Python-specific                 | Open Source              |
| Checkmarx | Enterprise SAST                 | Commercial               |

---

## Stage 4 — SCA (Software Composition Analysis)

### What Happens

All third-party libraries, open-source packages, and transitive dependencies are inventoried and checked against known vulnerability databases.

### Internal Steps

1. SCA tool reads dependency manifests and lock files.
2. Full dependency tree constructed — including **transitive dependencies**.
3. Each package cross-referenced against NIST NVD, OSV, GitHub Advisory Database.
4. CVE IDs and CVSS scores mapped to each finding.
5. License compliance checked — GPL, AGPL may violate internal policies.
6. SBOM generated in CycloneDX or SPDX format.
7. Pipeline blocked if Critical CVEs found in direct dependencies.

### CVSS Score Reference

| CVSS Score | Severity |
| ---------- | -------- |
| 9.0 – 10.0 | Critical |
| 7.0 – 8.9  | High     |
| 4.0 – 6.9  | Medium   |
| 0.1 – 3.9  | Low      |

---

## Stage 5 — Secrets Scanning

### What Happens

The entire Git history and codebase are scanned for accidentally committed secrets — API keys, passwords, tokens, and private certificates.

### Internal Steps

1. Regex-based detection matches known secret formats (AWS keys, GitHub tokens, JWT secrets, SSH private keys).
2. Entropy-based detection flags high-entropy random-looking strings.
3. Whitelisting applied via `.gitleaksignore` to exclude known false positives.
4. Any confirmed finding triggers immediate pipeline block and security team alert.

### Important Note

> Removing a secret from a later commit does NOT erase it from Git history. The key must be **rotated/revoked immediately** regardless of whether it has been removed.

---

## Stage 6 — Build & Push Container Image

### What Happens

The application is packaged into a Docker image using a multi-stage build and pushed to a container registry.

### Internal Steps

1. Multi-stage `Dockerfile` executed:
   - Build stage — compile inside a full SDK image
   - Runtime stage — copy artifacts into a minimal base image (`alpine`, `distroless`)
2. Image tagged with Git commit SHA (immutable reference).
3. CI runner authenticates to registry using injected credentials.
4. Image layers uploaded (delta push — only changed layers).
5. Image digest (SHA-256) recorded for downstream verification.

### Best Practices Enforced

- Pinned base image (no `FROM ubuntu:latest`)
- No secrets baked into the image
- Run as non-root user (`USER appuser`)
- `.dockerignore` excludes `.git`, test dirs, dev files

---

## Stage 7 — Container Image Scanning

### What Happens

The container image is scanned layer-by-layer for CVEs in OS packages, language runtimes, and bundled application dependencies.

### Internal Steps

1. Scanner unpacks each image layer.
2. Software inventory generated — all OS packages (dpkg/rpm/apk), language runtimes, app files.
3. Each package version matched against CVE databases.
4. Misconfigurations checked — root user, `privileged: true`, excessive capabilities.
5. Pipeline blocked if Critical CVEs with available fix are found.

### Tool Comparison

| Tool             | OS Scan | Secret Detection | Misconfiguration |
| ---------------- | ------- | ---------------- | ---------------- |
| Trivy            | Yes     | Yes              | Yes              |
| Amazon Inspector | Yes     | No               | Yes              |
| Clair            | Yes     | No               | No               |
| Anchore          | Yes     | Yes              | Yes              |

---

## Stage 8 — IaC Scanning (Terraform & Ansible)

### What Happens

All infrastructure definition files — Terraform configs, Ansible playbooks, Kubernetes manifests, and Helm charts — are scanned for security misconfigurations before any infrastructure is provisioned or configured.

### Internal Steps

**Terraform File Scanning:**

1. Scanner discovers all `.tf` files in the repository.
2. Parses each Terraform resource block and checks against security rule sets.
3. Checks performed:
   - S3 buckets — public access blocked?
   - Security groups — no `0.0.0.0/0` ingress on ports 22 (SSH), 3306 (MySQL), 5432 (Postgres)
   - IAM policies — no wildcard `*` actions or resources
   - RDS instances — encryption at rest enabled? deletion protection enabled?
   - EC2 instances — no public IPs assigned without explicit justification
   - CloudTrail / VPC Flow Logs — logging enabled?
   - KMS encryption applied to all sensitive resources
4. Findings mapped to CIS AWS Foundations Benchmark and compliance frameworks.

**Ansible Playbook Scanning (ansible-lint + Checkov):**

1. Scanner discovers all `.yml` playbooks and `roles/` directories.
2. ansible-lint applies rule checks:
   - No use of `command` or `shell` module when purpose-built modules exist
   - No `become: yes` (privilege escalation) without explicit justification
   - No `ignore_errors: true` hiding task failures
   - No hardcoded passwords or secrets in `vars:` blocks
   - Variables properly defined in `defaults/` and `vars/`
   - Tasks have `name:` labels for auditability
3. Checkov scans playbooks for:
   - SSH password authentication not disabled
   - Firewall rules not configured
   - File permissions set insecurely (world-writable files)
   - Ansible Vault not used for sensitive variables

**Kubernetes / Helm Scanning:**

1. Pod Security Standards validated (restricted/baseline).
2. RBAC rules checked for over-permissive ClusterRoles.
3. Network Policies existence verified.
4. Resource limits (CPU/memory) verified on all workloads.
5. `privileged: true` and `hostNetwork: true` flagged.

### Inputs

- Terraform `.tf` files and `terraform.tfvars`
- Ansible playbooks, roles, inventory files
- Kubernetes YAML manifests and Helm chart templates
- CloudFormation / ARM / Bicep templates

### Outputs

- Misconfiguration report per resource with rule ID, severity, file, line number, and remediation guidance
- CIS Benchmark compliance score
- Compliance framework mapping (PCI-DSS, SOC2, HIPAA)

### Failure Conditions

- Public S3 bucket or database with no encryption
- Security group with `0.0.0.0/0` on sensitive ports
- Ansible playbook with hardcoded credentials in vars
- IAM role with wildcard `*` permissions
- Kubernetes pod with `privileged: true`

### Tool Comparison

| Tool         | Terraform | Ansible | Kubernetes | CloudFormation |
| ------------ | --------- | ------- | ---------- | -------------- |
| Checkov      | Yes       | Yes     | Yes        | Yes            |
| tfsec        | Yes       | No      | No         | No             |
| ansible-lint | No        | Yes     | No         | No             |
| kube-score   | No        | No      | Yes        | No             |
| KICS         | Yes       | Yes     | Yes        | Yes            |

---

## Stage 9 — Infrastructure Provisioning (Terraform)

### What Happens

Terraform provisions and manages all cloud infrastructure required for the application — networking, compute, storage, databases, and security controls — in a repeatable, version-controlled, and auditable way.

### Core Concepts

**State Management:**

- Terraform maintains a **state file** (`.tfstate`) that tracks the real-world status of all managed resources.
- Remote state is stored in an S3 bucket with DynamoDB table for state locking — preventing concurrent modifications from multiple pipeline runs.
- State file contains sensitive data — access must be restricted via IAM policies.

**Plan vs Apply:**

- `terraform plan` — generates an execution plan showing exactly what changes will be made (create, modify, destroy). No infrastructure is changed.
- `terraform apply` — executes the plan and makes the actual changes.
- In the CI/CD pipeline: `plan` runs on every PR (output posted as a PR comment), `apply` runs only after PR merge and security gate approval.

**Workspaces / Environments:**

- Separate Terraform workspaces (or separate state files) for `dev`, `staging`, and `production`.
- Variable files (`terraform.tfvars`, `staging.tfvars`, `prod.tfvars`) control environment-specific values.
- Terragrunt manages DRY (Don't Repeat Yourself) configurations across environments.

### Internal Steps

1. Terraform backend is initialized — connects to remote state in S3 + DynamoDB.
2. Provider plugins downloaded and version-locked (`required_providers` block).
3. `terraform validate` — checks syntax and internal consistency of all `.tf` files.
4. `terraform plan` executes:
   - Current state is read from the remote backend
   - Desired state is computed from `.tf` files
   - Diff between current and desired states is calculated
   - Plan output shows: resources to create (+), modify (~), or destroy (-)
5. Plan output is reviewed — pipeline blocks if any **destroy** action targets production resources without explicit approval.
6. `terraform apply` executes the approved plan:
   - Resources are provisioned in dependency order (VPC before subnets, subnets before EC2)
   - State file is updated after each resource creation
   - Outputs (IP addresses, DNS names, ARNs) are stored as Terraform outputs
7. Outputs are exported as pipeline artifacts — passed to Ansible and deployment stages.

### What Terraform Provisions (Typical Application Stack)

| Resource Category | Examples                                                                 |
| ----------------- | ------------------------------------------------------------------------ |
| Networking        | VPC, Public/Private Subnets, Route Tables, Internet Gateway, NAT Gateway |
| Security          | Security Groups, NACLs, WAF rules, Shield                                |
| Compute           | EC2 instances, Auto Scaling Groups, Launch Templates                     |
| Containers        | ECS Cluster, ECS Task Definitions, EKS Cluster, Node Groups              |
| Database          | RDS (PostgreSQL/MySQL), ElastiCache (Redis), DynamoDB                    |
| Storage           | S3 buckets (with versioning, encryption, lifecycle rules)                |
| DNS & CDN         | Route 53 records, CloudFront distributions                               |
| Identity          | IAM roles, policies, instance profiles                                   |
| Secrets           | AWS Secrets Manager entries, KMS keys                                    |
| Monitoring        | CloudWatch Log Groups, Alarms, Dashboards                                |

### Terraform Security Controls in the Pipeline

- `terraform plan` output reviewed for unintended resource destruction before apply
- Sentinel policies (Terraform Cloud) enforce compliance rules — e.g., "all S3 buckets must have encryption enabled"
- Blast radius limited by separating state per module (network, compute, database in separate state files)
- `prevent_destroy = true` lifecycle rule set on production databases and S3 buckets
- All sensitive outputs marked `sensitive = true` — not printed in logs
- IAM role used by Terraform runner follows least-privilege principle

### Inputs

- Terraform `.tf` files from the repository
- Variable files (`staging.tfvars`, `prod.tfvars`)
- Remote state (current infrastructure state from S3)
- Pipeline-injected secrets (AWS credentials via IAM role or OIDC)

### Outputs

- Provisioned cloud infrastructure
- Updated remote state file
- Terraform outputs (IP addresses, DNS names, resource ARNs, ECS cluster names)
- Plan output report (number of resources added / changed / destroyed)

### Failure Conditions

- `terraform validate` fails — syntax errors in `.tf` files
- `terraform plan` detects destructive changes on protected resources — manual approval required
- `terraform apply` fails mid-run — partial state, requires investigation and targeted fix
- Remote state lock not released — another run is in progress
- AWS API errors — permissions, quota limits, resource conflicts

---

## Stage 10 — Configuration Management (Ansible)

### What Happens

Ansible connects to the servers provisioned by Terraform and configures them — installing software packages, applying OS hardening, managing users and permissions, configuring application services, and deploying application artifacts.

### Core Concepts

**Inventory:**

- Defines which hosts Ansible connects to and how they are grouped (e.g., `[webservers]`, `[dbservers]`, `[staging]`, `[production]`).
- **Dynamic inventory** is used in cloud environments — Ansible queries AWS/GCP/Azure APIs to discover the current list of running instances (using `aws_ec2` or `gcp_compute` inventory plugins).
- Host variables can be set per host or per group.

**Playbooks:**

- YAML files defining what tasks to execute on which hosts.
- A playbook contains one or more **plays**; each play contains one or more **tasks**.
- Tasks use **modules** — pre-built actions for specific operations (installing packages, copying files, managing services, creating users).

**Roles:**

- Reusable, self-contained units of automation bundled with tasks, handlers, templates, files, and variables.
- Roles from **Ansible Galaxy** (community) are used for common hardening tasks (e.g., `dev-sec.os-hardening`, `geerlingguy.docker`).

**Ansible Vault:**

- Encrypts sensitive variable files and strings (database passwords, API keys, TLS private keys) using AES-256.
- Vault password injected from the CI/CD secrets vault at runtime — never stored in the repository.

### Internal Steps

1. **Inventory resolution** — dynamic inventory plugin queries AWS for running EC2/ECS instances tagged for the target environment. Host list is built automatically from Terraform output.
2. **SSH connectivity verified** — Ansible tests connectivity to all target hosts using the pipeline's private key (injected from secrets vault).
3. **Playbook execution begins** — tasks execute in order:

   **OS Hardening Tasks:**
   - Update all OS packages to latest patched versions (`apt upgrade` / `yum update`)
   - Disable root SSH login (`PermitRootLogin no` in `sshd_config`)
   - Enforce SSH key-only authentication (disable password auth)
   - Configure `ufw` / `firewalld` — allow only required ports
   - Apply CIS Benchmark level 1 hardening rules (kernel parameters, sysctl settings)
   - Configure `fail2ban` — block IPs with repeated failed SSH attempts
   - Set file permission hardening (remove world-writable files, set `umask 027`)
   - Configure `auditd` — kernel-level audit logging for security events
   - Disable unnecessary services (bluetooth, avahi, cups)

   **User & Access Management:**
   - Create application service accounts (non-root, no shell login)
   - Deploy SSH public keys for authorized operators
   - Remove default/unused system accounts
   - Configure `sudo` rules — only authorized users get privilege escalation

   **Application Deployment Tasks:**
   - Install runtime dependencies (Python, Node.js, JRE as needed)
   - Deploy application configuration files from Jinja2 templates (rendered with environment-specific variables)
   - Configure reverse proxy (Nginx / Apache) — TLS termination, upstream proxy rules, security headers
   - Deploy TLS certificates (from AWS ACM or Let's Encrypt via `certbot`)
   - Configure systemd service units for application processes
   - Start and enable application services

   **Monitoring Agent Setup:**
   - Install and configure CloudWatch Agent / Datadog Agent / Prometheus node exporter
   - Configure log shipping to centralized logging (CloudWatch Logs, ELK stack, Splunk)

4. **Handlers triggered** — tasks that must run once after a set of changes (e.g., restart Nginx only after config changes, reload `sshd` after hardening).
5. **Idempotency verified** — re-running the playbook produces no changes if the system is already in the desired state.
6. **Post-task verification** — Ansible checks that services are running, ports are listening, and the application responds to health checks.

### Jinja2 Templating

- Configuration files (Nginx configs, app config files, `.env` equivalents) are written as Jinja2 templates with `{{ variable_name }}` placeholders.
- Variables come from:
  - `group_vars/` — variables shared across a group of hosts
  - `host_vars/` — variables specific to a single host
  - Ansible Vault encrypted files — for secrets
  - Terraform outputs — passed in as extra variables (`-e`)
- Templates rendered at deploy time — producing environment-specific config files with correct IP addresses, database endpoints, API URLs.

### Ansible Vault — Secrets Handling

- All sensitive values (DB passwords, API keys, TLS keys) stored in encrypted vault files.
- Vault files committed to the repository — safe because they are AES-256 encrypted.
- Vault password stored in CI/CD secrets manager (GitHub Secrets / AWS Secrets Manager).
- At runtime: `ansible-playbook --vault-password-file /tmp/vault_pass playbook.yml`
- No secrets ever appear in plain text in logs or pipeline output.

### Inputs

- Ansible playbooks and roles from the repository
- Dynamic inventory (auto-generated from AWS/cloud APIs using Terraform outputs)
- Vault-encrypted variable files
- Vault password (injected from secrets manager)
- SSH private key (injected from secrets manager)
- Terraform outputs (server IPs, DB endpoints, S3 bucket names, etc.)

### Outputs

- Fully configured, hardened servers ready to run the application
- Application services running and health-checked
- Ansible execution report (task results per host — ok, changed, failed, skipped)
- Idempotent state — re-running produces no unintended changes

### Failure Conditions

- SSH connectivity failure — runner cannot reach target hosts (security group or key issue)
- Task failure — package install fails, service fails to start, file permission error
- Vault decryption failure — wrong vault password
- Dynamic inventory returns empty host list — no running instances found
- Idempotency broken — re-running playbook causes unintended changes (playbook bug)

### Ansible Hardening Checks (Post-Run Verification)

| Check                | Expected Result                  |
| -------------------- | -------------------------------- |
| SSH root login       | Disabled                         |
| Password-based SSH   | Disabled                         |
| UFW / firewalld      | Active, only required ports open |
| fail2ban             | Active                           |
| auditd               | Active and logging               |
| World-writable files | None found                       |
| Application service  | Active and running               |
| TLS certificate      | Valid, not expired               |

---

## Stage 11 — Deploy to Staging

### What Happens

The verified container image is deployed to the staging environment — already provisioned by Terraform and hardened by Ansible — for dynamic security testing.

### Internal Steps

1. Deployment manifest updated with the new image digest from Stage 6.
2. Kubernetes rolling update / ECS task definition update initiated.
3. Health checks and readiness probes awaited.
4. Smoke tests executed — basic API availability checks.
5. Staging URL published as pipeline artifact for the DAST scanner.

### Staging Environment Requirements

- Provisioned by the same Terraform modules as production (environment variables differ)
- Configured by the same Ansible playbooks as production
- Isolated network — no access to production databases
- Seeded with anonymized / synthetic test data

---

## Stage 12 — DAST (Dynamic Application Security Testing)

### What Happens

The running staging application is actively probed with real HTTP requests simulating attacker behavior to find runtime vulnerabilities.

### Internal Steps

1. DAST tool configured with the staging URL.
2. Passive scan — spider/crawl all accessible endpoints and forms.
3. Active scan — inject attack payloads into every parameter, header, cookie, form field:
   - SQL injection, XSS, Path Traversal, XXE, SSRF, CSRF token checks
4. Responses analyzed for evidence of successful injection or data leakage.
5. Authenticated scan performed using test credentials.
6. Findings classified by severity, mapped to OWASP Top 10.

### What DAST Detects

- SQL Injection and Blind SQL Injection
- Reflected and Stored XSS
- CSRF (Cross-Site Request Forgery)
- Broken Authentication
- Missing security headers (HSTS, CSP, X-Frame-Options)
- IDOR (Insecure Direct Object Reference)
- SSRF (Server-Side Request Forgery)
- Directory Listing enabled
- Verbose error messages with stack traces

### SAST vs DAST

| Aspect              | SAST (Stage 3)              | DAST (Stage 12)               |
| ------------------- | --------------------------- | ----------------------------- |
| When                | Source code (pre-execution) | Running application (runtime) |
| What it finds       | Code-level vulnerabilities  | Runtime vulnerabilities       |
| False Positives     | Higher                      | Lower                         |
| Language dependency | Yes                         | No                            |

---

## Stage 13 — Security Gates & Policy Enforcement

### What Happens

All findings from every stage (SAST, SCA, Secrets, Container, IaC, Terraform, Ansible, DAST) are aggregated, evaluated against defined security policies, and a final PASS or BLOCK decision is made.

### Policy Types

| Policy                          | Trigger Condition                       | Action        |
| ------------------------------- | --------------------------------------- | ------------- |
| Zero Critical CVE               | Any Critical finding with fix available | Block         |
| Secrets Exposure                | Any confirmed secret detected           | Block + Alert |
| DAST OWASP Critical             | SQL Injection, RCE confirmed            | Block         |
| Terraform Destroy on Production | Destructive plan without approval       | Block         |
| Ansible Vault Not Used          | Plaintext secrets in playbooks          | Block         |
| IAM Wildcard Permission         | `*` actions in IAM policy               | Block         |
| License Violation               | GPL in proprietary product              | Block         |
| Container Root User             | Container runs as UID 0                 | Block         |
| Missing Security Headers        | HSTS, CSP absent                        | Warn          |

### Inputs

- Aggregated findings from Stages 3, 4, 5, 7, 8, 12
- Terraform plan output (destructive changes check)
- Ansible-lint and Checkov results for playbooks
- Policy definitions (OPA Rego rules / Conftest YAML)

### Outputs

- Gate decision: PASS or BLOCK
- Detailed report of which policies failed and which findings triggered them
- Exception log if manual override applied

---

## Stage 14 — Deploy to Production

### What Happens

The verified, security-approved application is deployed to production infrastructure — already provisioned by Terraform and configured by Ansible — using a safe deployment strategy.

### Internal Steps

1. Production deployment initiated after PASS gate decision.
2. Deployment strategy applied:
   - **Blue/Green** — new version launched alongside old; traffic switched atomically
   - **Canary** — 5% traffic to new version first, expanded if stable
   - **Rolling Update** — pods replaced one-by-one while maintaining availability
3. Image referenced by immutable SHA-256 digest — never by `latest` tag.
4. Production secrets injected at runtime from AWS Secrets Manager / HashiCorp Vault — never from the image or repository.
5. Post-deploy health checks monitored.
6. Automatic rollback triggered if error rate spikes or health checks fail.
7. Deployment event recorded in audit log.

### Production Security Controls

- Image signature verified (Cosign / Notary) before deployment
- Runtime security agent active (Falco, AWS GuardDuty)
- Terraform-managed security groups and NACLs enforced
- Ansible-hardened OS baseline on all nodes
- WAF rules updated for new endpoints
- Immutable infrastructure — no SSH into production containers

---

## Stage 15 — Dashboard & Vulnerability Management

### What Happens

All security findings from every pipeline run are centralized, deduplicated, assigned, and tracked over time.

### Key Metrics Tracked

| Metric                        | Description                         | Target                    |
| ----------------------------- | ----------------------------------- | ------------------------- |
| MTTR (Mean Time To Remediate) | Avg time from detection to fix      | Critical < 24h, High < 7d |
| Open Critical Findings        | Count of unresolved Critical issues | 0                         |
| Security Debt                 | Cumulative unresolved findings      | Trending downward         |
| False Positive Rate           | % findings marked as false positive | < 20%                     |
| Terraform Drift Events        | Times live infra diverged from IaC  | 0                         |
| Ansible Compliance Rate       | % hosts passing CIS Benchmark       | 100%                      |

---

## Stage 16 — Scheduled Security Scans

### What Happens

Independent of code changes, deep security assessments run on a schedule to catch new CVEs, configuration drift, and threats that emerge between deployments.

### Scheduled Scan Types

**Nightly Scans:**

- Re-scan deployed container image with updated vulnerability database
- Re-run SCA on production dependencies against latest CVE feeds
- Full Git history secrets scan

**Weekly Scans:**

- Full DAST scan against staging
- `terraform plan` drift detection — compare live infrastructure against IaC definitions
- Ansible compliance re-run — verify all hosts still meet hardening baseline
- CIS Benchmark re-evaluation of all running cloud resources

**Monthly Scans:**

- Full penetration testing simulation (automated)
- License compliance audit
- Full SBOM regeneration and archival
- Cloud Security Posture Management (CSPM) assessment

### Drift Detection (Terraform)

- A scheduled `terraform plan` is run against the production environment without applying.
- If the plan output shows any changes — it means someone manually modified infrastructure outside of Terraform (configuration drift).
- Drift alerts are sent to the security and infrastructure teams.
- All infrastructure changes must flow through the pipeline (IaC-only policy).

### Compliance Re-Runs (Ansible)

- Ansible playbooks re-run in **check mode** (`--check`) against production hosts periodically.
- Check mode simulates what would change without actually making changes.
- Any detected configuration drift (manual changes to OS hardening, firewall rules, user accounts) is flagged.

---

# Complete Low-Level DevSecOps Flow Summary

```
Git Push / Pull Request
          |
[ STAGE 1: TRIGGER ]
  - Webhook received, runner allocated
  - Repo cloned at commit SHA
  - Secrets injected from vault
          |
[ STAGE 2: BUILD & UNIT TESTING ]
  - Dependencies installed
  - Source compiled / bundled
  - Unit tests + coverage check
          |
[ STAGE 3: SAST ]
  - AST parsing + taint analysis
  - OWASP / CWE rule matching
  - SARIF report generated
          |
[ STAGE 4: SCA ]
  - Dependency tree built
  - CVE database lookup
  - License check + SBOM generated
          |
[ STAGE 5: SECRETS SCANNING ]
  - Regex + entropy detection
  - Full git history scan
  - Immediate block on any finding
          |
[ STAGE 6: BUILD & PUSH CONTAINER ]
  - Multi-stage Docker build
  - Tagged with commit SHA digest
  - Pushed to registry
          |
[ STAGE 7: CONTAINER IMAGE SCANNING ]
  - Layer-by-layer CVE scan
  - OS + runtime packages scanned
  - Root user / privilege checks
          |
[ STAGE 8: IaC SCANNING (Terraform + Ansible) ]
  - Terraform .tf files scanned (tfsec, Checkov)
  - Ansible playbooks linted (ansible-lint, Checkov)
  - Kubernetes manifests / Helm charts scanned
  - CIS Benchmark mapping + compliance report
          |
[ STAGE 9: INFRASTRUCTURE PROVISIONING (Terraform) ]
  - Remote state initialized (S3 + DynamoDB lock)
  - terraform validate --> terraform plan
  - Plan reviewed: no destructive changes on prod
  - terraform apply --> VPC, EC2, EKS, RDS, S3, IAM
  - Outputs exported (IPs, ARNs, DNS names)
          |
[ STAGE 10: CONFIGURATION MANAGEMENT (Ansible) ]
  - Dynamic inventory built from AWS + Terraform outputs
  - OS hardening applied (SSH, firewall, auditd, fail2ban)
  - Application packages and config deployed via Jinja2 templates
  - Secrets decrypted from Ansible Vault at runtime
  - Services started + health checked
  - Idempotency verified
          |
[ STAGE 11: DEPLOY TO STAGING ]
  - Image deployed to Terraform-provisioned staging
  - Ansible-configured servers receive deployment
  - Health + readiness probes confirmed
  - Staging URL published for DAST
          |
[ STAGE 12: DAST ]
  - Spider + crawl all endpoints
  - Active payload injection (SQLi, XSS, SSRF...)
  - Authenticated scan of protected routes
  - OWASP Top 10 coverage report
          |
[ STAGE 13: SECURITY GATES ]
  - All findings aggregated (Stages 3-12)
  - Terraform plan destruction check
  - Ansible vault + hardening compliance check
  - PASS --> proceed | BLOCK --> halt + alert
          |
[ STAGE 14: DEPLOY TO PRODUCTION ]
  - Image verified by SHA-256 digest
  - Canary / Blue-Green deployment strategy
  - Runtime secrets injected from AWS Secrets Manager
  - Auto-rollback on health check failure
          |
[ STAGE 15: DASHBOARD & MONITORING ]
  - Findings deduplicated + tracked
  - SLAs assigned + compliance reports
  - Terraform drift events monitored
  - Ansible compliance rate measured
          |
[ STAGE 16: SCHEDULED SCANS ]
  - Nightly: image + SCA re-scan
  - Weekly: DAST + Terraform drift plan + Ansible check mode
  - Monthly: SBOM + CSPM + pentest simulation
  - New CVE on deployed asset --> emergency alert
```

---

## Security Severity Reference

| Severity      | CVSS Range | Response SLA        | Pipeline Action           |
| ------------- | ---------- | ------------------- | ------------------------- |
| Critical      | 9.0 – 10.0 | Fix within 24 hours | Block pipeline            |
| High          | 7.0 – 8.9  | Fix within 7 days   | Block pipeline            |
| Medium        | 4.0 – 6.9  | Fix within 30 days  | Warn, allow with approval |
| Low           | 0.1 – 3.9  | Fix within 90 days  | Log only                  |
| Informational | N/A        | Best effort         | Log only                  |

---

## Terraform vs Ansible — Roles Compared

| Aspect                   | Terraform                                | Ansible                                    |
| ------------------------ | ---------------------------------------- | ------------------------------------------ |
| Primary Role             | Infrastructure provisioning              | Configuration management                   |
| What it manages          | Cloud resources (VPC, EC2, RDS, S3, IAM) | OS-level config, packages, services, users |
| Language                 | HCL (HashiCorp Configuration Language)   | YAML (playbooks + Jinja2 templates)        |
| State tracking           | Yes — remote state file                  | No — idempotent re-runs verify state       |
| Secrets handling         | Sensitive outputs + Vault integration    | Ansible Vault (AES-256)                    |
| Execution model          | Declarative (desired state)              | Procedural / Declarative hybrid            |
| When it runs in pipeline | After IaC scanning, before Ansible       | After Terraform, before staging deploy     |
| Drift detection          | terraform plan (scheduled)               | Ansible --check mode (scheduled)           |
| Security scanning tool   | tfsec, Checkov                           | ansible-lint, Checkov                      |

---

## Key Standards & Frameworks Referenced

| Framework                  | Relevance                                          |
| -------------------------- | -------------------------------------------------- |
| OWASP Top 10               | Web vulnerability classification (SAST, DAST)      |
| CWE                        | Code-level weakness taxonomy (SAST)                |
| CVE / NVD                  | Known vulnerability identifiers (SCA, Container)   |
| CVSS v3.1                  | Vulnerability severity scoring                     |
| CIS Benchmarks             | Infrastructure hardening (IaC, Ansible, Container) |
| CIS AWS Foundations        | Terraform resource security checks                 |
| NIST SP 800-190            | Container security guidance                        |
| SBOM / CycloneDX / SPDX    | Software bill of materials standards               |
| SARIF                      | Static analysis result interchange format          |
| SOC2 / PCI-DSS / ISO 27001 | Compliance frameworks (Dashboard, Reporting)       |
