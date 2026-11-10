# kubernetes-gitops-platform

Production-grade GitOps reference architecture with ArgoCD, Terraform, multi-cluster networking, Vault, and automated certificate management.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Git Repo (Source of Truth)             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  clusters/  │  │  apps/      │  │  infra/     │          │
│  │  (per-env)  │  │  (helm/     │  │  (terraform)│          │
│  │             │  │   kustomize)│  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      ArgoCD (GitOps Engine)                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Cluster A  │  │  Cluster B  │  │  Cluster N  │          │
│  │  (prod)     │  │  (staging)  │  │  (dev)      │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
       ┌────────────┐  ┌────────────┐  ┌────────────┐
       │   Vault    │  │  cert-     │  │  External  │
       │  (Secrets) │  │  manager   │  │  DNS / LB  │
       └────────────┘  └────────────┘  └────────────┘
```

## Components

| Layer | Tool | Purpose |
|-------|------|---------|
| **GitOps** | ArgoCD | Declarative continuous delivery |
| **IaC** | Terraform | Infrastructure provisioning (AWS/GCP/Azure) |
| **Secrets** | HashiCorp Vault + External Secrets Operator | Centralized secret management |
| **Certificates** | cert-manager + Let's Encrypt | Automated TLS lifecycle |
| **Networking** | Cilium / Istio | CNI, service mesh, network policies |
| **Observability** | Prometheus + Grafana + Tempo + Loki | Full stack observability |
| **Policy** | Kyverno / Gatekeeper | Admission control, compliance |

## Repository Structure

```
.
├── clusters/
│   ├── production/
│   │   ├── argocd-applications.yaml
│   │   └── cluster-config.yaml
│   ├── staging/
│   └── development/
├── apps/
│   ├── platform/
│   │   ├── argocd/
│   │   ├── cert-manager/
│   │   ├── external-secrets/
│   │   └── monitoring/
│   ├── workloads/
│   │   ├── api-gateway/
│   │   └── ml-inference/
│   └── data/
│       ├── postgresql/
│       └── redis/
├── infra/
│   ├── aws/
│   │   ├── vpc/
│   │   ├── eks/
│   │   └── rds/
│   └── gcp/
└── bootstrap/
    └── install-argocd.sh
```

## Quick Start

```bash
# Bootstrap ArgoCD on a new cluster
./bootstrap/install-argocd.sh --cluster production

# Deploy platform components
kubectl apply -k clusters/production/

# Verify
argocd app list
```

## Topics

`kubernetes` `terraform` `argocd` `gitops` `platform-engineering` `vault` `cert-manager` `cilium` `observability`