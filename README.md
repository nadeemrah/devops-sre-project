# DevOps SRE Project — Two-tier app on AWS EKS

## Overview
This repository contains a complete end-to-end solution for deploying a simple two-tier web application (FastAPI backend + Nginx frontend) to an Amazon EKS cluster provisioned via Terraform. It includes CI (GitHub Actions), GitOps (Argo CD), and an observability stack (Prometheus/Grafana + Fluentd -> CloudWatch).

## Architecture 

<img width="4800" height="2714" alt="image" src="https://github.com/user-attachments/assets/4192d41f-72b9-4d34-a5ce-f3c8e25004b0" />


- Terraform provisions VPC and EKS across multiple AZs.
- Node groups:
  - `system` (On-Demand) for control/critical workload.
  - `app_spot` (Spot) for application pods.
- Applications deployed in `app` namespace via Kubernetes manifests.
- Ingress implemented using AWS ALB ingress controller (annotations in ingress).
- CI builds images and pushes to ECR; manifests are updated with image tags.
- Argo CD watches the repository and applies manifests automatically if configured.
- Observability: `kube-prometheus-stack` + Fluentd -> CloudWatch.

## What’s included
- `app-backend/` — FastAPI code + Dockerfile
- `app-frontend/` — static `index.html` + Dockerfile
- `k8s/` — Kubernetes manifests (Deployments, Services, Ingress, ArgoCD App)
- `infra/` — Terraform (VPC, NACL, EKS + nodegroups, ECR, Argocd , ALB Controller, Fluentd, Prometheus Helm, Prometheus rules)
- `ci/.github/workflows/ci-cd.yaml` — GitHub Actions workflow
- `observability/` — Helm values for prometheus

## Quick start (summary)
> **Prereqs**: AWS account, AWS CLI configured, Terraform installed, kubectl, Helm, GitHub repo with secrets.

1. Clone this repository
```bash
git clone https://github.com/nadeemrah/devops-sre-project.git
cd devops-sre-project/infra
terraform init
terraform plan 
terraform apply
```

This provisions:

- VPC with private/public subnets along with NACL.
- EKS cluster + node groups (On-Demand + Spot).
- ECR repository for app-frontend and app-backend.
- ALB Ingress Controller Installed in EKS.
- Argocd Installed in EKS.
- Fluend installed in EKS.
- Prometheus and Grafana installed in EKS.

Once the Infra is created, run the github action pipeline to deploy app-frontend, app-backend and ingress in eks.


##  Reliability Plan – Debugging a Production Incident

**Scenario:** A sudden **50% increase in API error rates** has been detected in production.

### Step 1 – Detect & Confirm

* **Alerting**: Prometheus Alertmanager triggers an alert when error rates cross the defined SLO threshold.
* **Dashboard Check**: Open Grafana dashboard for RED metrics (Rate, Errors, Duration) of the backend API to confirm spike.

### Step 2 – Scope the Impact

* Identify if the errors affect **all users** or a specific subset (e.g., region, service, version).
* Check the **frontend status** (Nginx) and whether it’s still serving static content.

### Step 3 – Investigate Metrics

* Review **Prometheus metrics**:

  * **Error Rate** (5xx, 4xx).
  * **Latency** (request duration).
  * **Throughput** (requests/sec).
* Check **Kubernetes Node & Pod Utilization** (CPU, memory, restarts).

### Step 4 – Investigate Logs

* Use **CloudWatch Logs (via Fluentd)** to drill into:

  * Backend pod logs for stack traces or timeouts.
  * Nginx ingress logs for failed upstream connections.
  * System-level logs for node pressure, eviction, or OOM kills.

### Step 5 – Identify Root Cause

* **Application bug** → correlate errors with recent deployment via Argo CD history.
* **Infrastructure issue** → node failure, spot instance eviction, or networking issue.
* **External dependency issue** → DNS resolution or upstream API failure.

### Step 6 – Mitigation & Recovery

* **Rollback** the application to the last stable version via Argo CD.
* **Scale out** backend pods or adjust autoscaler thresholds if load-related.
* **Replace unhealthy nodes** if the cluster shows infra-level issues.

### Step 7 – Postmortem & Continuous Improvement

* Document the timeline, root cause, and resolution.
* Update **SLOs & alerts** if gaps were discovered.
* Add **runbooks** for recurring issues.

