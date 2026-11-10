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

## Prerequisites

- Kubernetes clusters (EKS/GKE/AKS) with admin access
- kubectl configured for target clusters
- ArgoCD CLI (`argocd`)
- Terraform >= 1.6
- Helm >= 3.12
- Vault >= 1.15 (or HCP Vault)
- Cloudflare/Route53 for DNS (optional)

## Bootstrap

### 1. Install ArgoCD

```bash
# Install ArgoCD with custom values
./bootstrap/install-argocd.sh \
  --cluster production \
  --namespace argocd \
  --values bootstrap/values-production.yaml
```

### 2. Configure Repository Access

```bash
# Add this repo to ArgoCD
argocd repo add https://github.com/smahud/kubernetes-gitops-platform \
  --username <github-user> \
  --password <github-token>

# Or use SSH
argocd repo add git@github.com:smahud/kubernetes-gitops-platform.git \
  --ssh-private-key-path ~/.ssh/id_ed25519
```

### 3. Deploy Platform Applications

```bash
# Apply cluster-specific configuration
kubectl apply -k clusters/production/

# This creates Application resources that ArgoCD will sync
```

## Cluster Configuration

Each cluster has a `cluster-config.yaml` defining:

```yaml
# clusters/production/cluster-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
  namespace: argocd
data:
  cluster_name: "production"
  environment: "production"
  region: "us-east-1"
  domain: "prod.example.com"
  ingress_class: "nginx"
  cert_issuer: "letsencrypt-prod"
  monitoring_retention: "30d"
  log_retention: "7d"
```

## Platform Applications

### ArgoCD (Self-managed)

```yaml
# apps/platform/argocd/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/smahud/kubernetes-gitops-platform
    targetRevision: main
    path: apps/platform/argocd
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Cert-Manager

Automated certificate management with Let's Encrypt:

```yaml
# apps/platform/cert-manager/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  source:
    repoURL: https://github.com/smahud/kubernetes-gitops-platform
    targetRevision: main
    path: apps/platform/cert-manager
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
```

**ClusterIssuer** for production:

```yaml
# apps/platform/cert-manager/clusterissuer-prod.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: certs@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

### External Secrets Operator

Sync secrets from Vault to Kubernetes:

```yaml
# apps/platform/external-secrets/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: external-secrets
spec:
  source:
    repoURL: https://github.com/smahud/kubernetes-gitops-platform
    targetRevision: main
    path: apps/platform/external-secrets
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets
```

**ClusterSecretStore** for Vault:

```yaml
# apps/platform/external-secrets/clustersecretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
```

**ExternalSecret** example:

```yaml
# apps/workloads/api-gateway/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-gateway-secrets
  namespace: api-gateway
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-backend
  target:
    name: api-gateway-secrets
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: production/api-gateway
        property: database_url
    - secretKey: redis-url
      remoteRef:
        key: production/api-gateway
        property: redis_url
```

### Monitoring Stack

Full observability with Prometheus, Grafana, Tempo, Loki:

```yaml
# apps/platform/monitoring/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring
  namespace: monitoring
spec:
  source:
    repoURL: https://github.com/smahud/kubernetes-gitops-platform
    targetRevision: main
    path: apps/platform/monitoring
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
```

Components:
- **Prometheus Operator** - Metrics collection
- **Grafana** - Dashboards
- **Tempo** - Distributed tracing
- **Loki** - Log aggregation
- **Alertmanager** - Alert routing

## Workload Applications

### API Gateway

```yaml
# apps/workloads/api-gateway/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-gateway
  namespace: api-gateway
spec:
  source:
    repoURL: https://github.com/smahud/kubernetes-gitops-platform
    targetRevision: main
    path: apps/workloads/api-gateway
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: api-gateway
```

### ML Inference

```yaml
# apps/workloads/ml-inference/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ml-inference
  namespace: ml-inference
spec:
  source:
    repoURL: https://github.com/smahud/kubernetes-gitops-platform
    targetRevision: main
    path: apps/workloads/ml-inference
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ml-inference
```

## Data Layer

### PostgreSQL (CloudNativePG)

```yaml
# apps/data/postgresql/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: postgresql
  namespace: postgresql
spec:
  source:
    repoURL: https://github.com/smahud/kubernetes-gitops-platform
    targetRevision: main
    path: apps/data/postgresql
  destination:
    server: https://kubernetes.default.svc
    namespace: postgresql
```

### Redis

```yaml
# apps/data/redis/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis
  namespace: redis
spec:
  source:
    repoURL: https://github.com/smahud/kubernetes-gitops-platform
    targetRevision: main
    path: apps/data/redis
  destination:
    server: https://kubernetes.default.svc
    namespace: redis
```

## Infrastructure (Terraform)

### AWS EKS

```hcl
# infra/aws/eks/main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      name           = "general"
      instance_types = ["m6i.xlarge"]
      capacity_type  = "ON_DEMAND"

      min_size     = 3
      max_size     = 20
      desired_size = 5
    }
    gpu = {
      name           = "gpu"
      instance_types = ["g5.2xlarge"]
      capacity_type  = "SPOT"

      min_size     = 0
      max_size     = 10
      desired_size = 0
    }
  }
}
```

### GCP GKE

```hcl
# infra/gcp/gke/main.tf
module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 30.0"

  project_id   = var.project_id
  name         = var.cluster_name
  region       = var.region
  network      = module.vpc.network_name
  subnetwork   = module.vpc.subnets[0].name

  node_pools = [
    {
      name         = "general"
      machine_type = "e2-standard-4"
      min_count    = 3
      max_count    = 20
    },
    {
      name         = "gpu"
      machine_type = "a2-highgpu-1g"
      min_count    = 0
      max_count    = 5
      accelerator = {
        type  = "nvidia-tesla-a100"
        count = 1
      }
    }
  ]
}
```

## Networking

### Cilium CNI

```yaml
# apps/platform/cilium/values.yaml
cilium:
  kubeProxyReplacement: true
  ipam:
    mode: "kubernetes"
  hubble:
    enabled: true
    metrics:
      enabled:
        - dns:query
        - drop
        - tcp
        - flow
        - icmp
        - http
  networkPolicy:
    enabled: true
```

### Istio Service Mesh

```yaml
# apps/platform/istio/values.yaml
pilot:
  configmap:
    enableAutoMtls: true
    enableHbone: true
global:
  meshID: mesh1
  multiCluster:
    clusterName: production
  mtls:
    enabled: true
```

## Policy & Compliance

### Kyverno Policies

```yaml
# apps/platform/kyverno/policies/restrict-latest-tag.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-latest-tag
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-image-tag
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "Container image must not use 'latest' tag"
        pattern:
          spec:
            containers:
              - image: "!*:latest"
            initContainers:
              - image: "!*:latest"
```

## Operations

### Daily Operations

```bash
# Check ArgoCD application status
argocd app list

# Get sync status for specific app
argocd app get api-gateway

# Force sync an application
argocd app sync api-gateway

# View application diff
argocd app diff api-gateway

# Rollback to previous version
argocd app rollback api-gateway 3
```

### Disaster Recovery

```bash
# Backup ArgoCD applications
argocd app list -o json > argocd-backup-$(date +%Y%m%d).json

# Restore from backup
cat argocd-backup-20240115.json | jq -r '.[] | .metadata.name' | xargs -I {} argocd app create {} --from-json
```

### Upgrade Procedure

1. Update Helm chart versions in `apps/*/Chart.yaml`
2. Update container images in values files
3. Create PR with changes
4. ArgoCD auto-syncs on merge (if automated)
5. Verify rollout: `kubectl rollout status deployment/<name> -n <namespace>`

## Security

- All secrets stored in Vault, synced via External Secrets Operator
- Network policies enforce zero-trust between namespaces
- Admission controllers (Kyverno) enforce security policies
- Regular vulnerability scanning with Trivy
- RBAC least-privilege for all service accounts
- Audit logging enabled on all clusters

## Monitoring

- **Infrastructure**: Node exporter, kube-state-metrics, cAdvisor
- **Application**: Prometheus Operator ServiceMonitors
- **Tracing**: Tempo with OpenTelemetry collectors
- **Logs**: Loki with Promtail
- **Alerts**: Alertmanager with PagerDuty/Slack/Email routes

## Topics

`kubernetes` `terraform` `argocd` `gitops` `platform-engineering` `vault` `cert-manager` `cilium` `observability`