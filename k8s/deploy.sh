#!/bin/bash
# =============================================================================
# Quick deploy iDempiere to k3s
# =============================================================================
# Usage:
#   ./k8s/deploy.sh          # Deploy everything (PostgreSQL + iDempiere)
#   ./k8s/deploy.sh app      # Deploy only iDempiere (external DB)
#   ./k8s/deploy.sh delete   # Remove everything
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "${1:-all}" in
  all)
    echo "==> Creating namespace..."
    kubectl apply -f "$SCRIPT_DIR/namespace.yaml"

    echo "==> Applying secrets..."
    kubectl apply -f "$SCRIPT_DIR/secret.yaml"

    echo "==> Applying configmap..."
    kubectl apply -f "$SCRIPT_DIR/configmap.yaml"

    echo "==> Deploying PostgreSQL..."
    kubectl apply -f "$SCRIPT_DIR/postgres.yaml"

    echo "==> Waiting for PostgreSQL to be ready..."
    kubectl -n idempiere wait --for=condition=ready pod -l app.kubernetes.io/name=postgres --timeout=120s

    echo "==> Deploying iDempiere..."
    kubectl apply -f "$SCRIPT_DIR/deployment.yaml"
    kubectl apply -f "$SCRIPT_DIR/service.yaml"
    kubectl apply -f "$SCRIPT_DIR/ingress.yaml"

    echo ""
    echo "==> Deployment complete!"
    echo "    Monitor: kubectl -n idempiere get pods -w"
    echo "    Logs:    kubectl -n idempiere logs -f deployment/idempiere"
    echo "    Access:  http://erp.local (after DNS/hosts config)"
    ;;

  app)
    echo "==> Deploying iDempiere only (expects external PostgreSQL)..."
    kubectl apply -f "$SCRIPT_DIR/namespace.yaml"
    kubectl apply -f "$SCRIPT_DIR/secret.yaml"
    kubectl apply -f "$SCRIPT_DIR/configmap.yaml"
    kubectl apply -f "$SCRIPT_DIR/deployment.yaml"
    kubectl apply -f "$SCRIPT_DIR/service.yaml"
    kubectl apply -f "$SCRIPT_DIR/ingress.yaml"

    echo ""
    echo "==> App deployment complete!"
    echo "    Make sure DB_HOST in configmap points to your PostgreSQL."
    ;;

  delete)
    echo "==> Removing iDempiere deployment..."
    kubectl delete -f "$SCRIPT_DIR/ingress.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/service.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/deployment.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/postgres.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/configmap.yaml" --ignore-not-found
    kubectl delete -f "$SCRIPT_DIR/secret.yaml" --ignore-not-found
    echo "==> Done. Namespace 'idempiere' preserved (delete manually if needed)."
    ;;

  *)
    echo "Usage: $0 {all|app|delete}"
    exit 1
    ;;
esac
