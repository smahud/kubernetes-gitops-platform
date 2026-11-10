#!/bin/bash
# install-argocd.sh - Bootstrap ArgoCD on a Kubernetes cluster

set -euo pipefail

CLUSTER=""
NAMESPACE="argocd"
VALUES_FILE=""
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $0 --cluster <name> [options]

Options:
  --cluster <name>       Cluster name (production, staging, development)
  --namespace <ns>       ArgoCD namespace (default: argocd)
  --values <file>        Custom values file
  --dry-run              Print commands without executing
  -h, --help             Show this help

Examples:
  $0 --cluster production
  $0 --cluster staging --values bootstrap/values-staging.yaml
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --values)
            VALUES_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$CLUSTER" ]]; then
    echo "Error: --cluster is required"
    usage
    exit 1
fi

# Validate cluster name
if [[ ! "$CLUSTER" =~ ^(production|staging|development)$ ]]; then
    echo "Error: cluster must be one of: production, staging, development"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CLUSTER_DIR="$REPO_ROOT/clusters/$CLUSTER"

echo "Bootstrapping ArgoCD for cluster: $CLUSTER"
echo "Namespace: $NAMESPACE"
echo "Cluster config: $CLUSTER_DIR"

# Check prerequisites
check_prereqs() {
    local missing=()
    command -v kubectl >/dev/null || missing+=("kubectl")
    command -v helm >/dev/null || missing+=("helm")
    command -v argocd >/dev/null || missing+=("argocd")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing required tools: ${missing[*]}"
        exit 1
    fi
}

check_prereqs

# Verify kubectl context
CURRENT_CONTEXT=$(kubectl config current-context)
echo "Current kubectl context: $CURRENT_CONTEXT"
read -p "Continue with this context? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 1
fi

# Add ArgoCD Helm repo
run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] $*"
    else
        eval "$@"
    fi
}

run_cmd helm repo add argo https://argoproj.github.io/argo-helm
run_cmd helm repo update

# Create namespace
run_cmd kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
HELM_ARGS=(
    upgrade --install argocd argo/argo-cd
    --namespace "$NAMESPACE"
    --create-namespace
    --version 7.7.0
    --set server.service.type=LoadBalancer
    --set server.ingress.enabled=true
    --set server.ingress.ingressClassName=nginx
    --set configs.params."server\.insecure"=true
    --set dex.enabled=false
    --set redis-ha.enabled=true
    --set controller.replicas=2
    --set repoServer.replicas=2
    --set server.replicas=2
    --wait
    --timeout 10m
)

if [[ -n "$VALUES_FILE" && -f "$VALUES_FILE" ]]; then
    HELM_ARGS+=(--values "$VALUES_FILE")
fi

# Check for cluster-specific values
if [[ -f "$CLUSTER_DIR/argocd-values.yaml" ]]; then
    HELM_ARGS+=(--values "$CLUSTER_DIR/argocd-values.yaml")
fi

run_cmd "${HELM_ARGS[@]}"

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD server..."
run_cmd kubectl wait --for=condition=available deployment/argocd-server -n "$NAMESPACE" --timeout=300s

# Get initial admin password
echo "Retrieving initial admin password..."
ADMIN_PASSWORD=$(run_cmd kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ADMIN_PASSWORD"

# Login to ArgoCD
ARGOCD_SERVER=$(run_cmd kubectl -n "$NAMESPACE" get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [[ -z "$ARGOCD_SERVER" ]]; then
    ARGOCD_SERVER=$(run_cmd kubectl -n "$NAMESPACE" get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

if [[ -z "$ARGOCD_SERVER" ]]; then
    echo "Warning: Could not determine ArgoCD server address. Using port-forward."
    echo "Run: kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
    ARGOCD_SERVER="localhost:8080"
fi

echo "ArgoCD server: $ARGOCD_SERVER"

if [[ "$DRY_RUN" != "true" ]]; then
    argocd login "$ARGOCD_SERVER" --username admin --password "$ADMIN_PASSWORD" --insecure
    echo "Logged in to ArgoCD"
fi

# Apply cluster config
if [[ -f "$CLUSTER_DIR/cluster-config.yaml" ]]; then
    echo "Applying cluster config..."
    run_cmd kubectl apply -f "$CLUSTER_DIR/cluster-config.yaml"
fi

# Apply ArgoCD applications
if [[ -f "$CLUSTER_DIR/argocd-applications.yaml" ]]; then
    echo "Applying ArgoCD applications..."
    run_cmd kubectl apply -f "$CLUSTER_DIR/argocd-applications.yaml"
fi

echo ""
echo "=========================================="
echo "ArgoCD bootstrap complete for $CLUSTER"
echo "=========================================="
echo "Server: https://$ARGOCD_SERVER"
echo "Username: admin"
echo "Password: $ADMIN_PASSWORD"
echo ""
echo "Next steps:"
echo "1. Change admin password: argocd account update-password"
echo "2. Add repository: argocd repo add <repo-url>"
echo "3. Create applications or apply clusters/$CLUSTER/argocd-applications.yaml"
echo ""