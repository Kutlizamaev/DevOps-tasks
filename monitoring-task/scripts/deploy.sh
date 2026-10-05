#!/usr/bin/env bash

set -Eeuo pipefail

TAG="latest"
NAMESPACE="fanil20261005"

while getopts "t:" opt; do
    case "$opt" in
        t)
            TAG="$OPTARG"
            ;;
        *)
            echo "Использование: $0 [-t tag]"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "========================================"
echo "Deploying DevOps monitoring project"
echo "Image tag: ${TAG}"
echo "Namespace: ${NAMESPACE}"
echo "========================================"

kubectl create namespace "$NAMESPACE" \
    --dry-run=client \
    -o yaml | kubectl apply -f -

echo
echo "Deploying application..."

sed "s/IMAGE_TAG/${TAG}/g" \
    k8s/app-deployment.yaml |
    kubectl apply \
        -n "$NAMESPACE" \
        -f -

kubectl apply \
    -n "$NAMESPACE" \
    -f k8s/app-service.yaml

echo
echo "Deploying Prometheus..."

kubectl apply \
    -n "$NAMESPACE" \
    -f monitoring/prometheus-config.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f monitoring/prometheus-deployment.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f monitoring/prometheus-service.yaml

echo
echo "Deploying Loki and Promtail..."

kubectl apply \
    -n "$NAMESPACE" \
    -f monitoring/loki-config.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f monitoring/loki-deployment.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f monitoring/loki-service.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f monitoring/promtail-config.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f monitoring/promtail-daemonset.yaml

echo
echo "Deploying Grafana..."

kubectl apply \
    -n "$NAMESPACE" \
    -f grafana/grafana-configmaps.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f grafana/grafana-dashboard-configmap.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f grafana/grafana-deployment.yaml

kubectl apply \
    -n "$NAMESPACE" \
    -f grafana/grafana-service.yaml

echo
echo "Waiting for application..."

kubectl rollout status \
    deployment/monitoring-app \
    -n "$NAMESPACE" \
    --timeout=180s

echo
echo "Waiting for Prometheus..."

kubectl rollout status \
    deployment/prometheus \
    -n "$NAMESPACE" \
    --timeout=180s

echo
echo "Waiting for Loki..."

kubectl rollout status \
    deployment/loki \
    -n "$NAMESPACE" \
    --timeout=180s

echo
echo "Waiting for Grafana..."

kubectl rollout status \
    deployment/grafana \
    -n "$NAMESPACE" \
    --timeout=180s

echo
echo "========================================"
echo "Deployment completed"
echo "========================================"

kubectl get pods \
    -n "$NAMESPACE"

echo

kubectl get services \
    -n "$NAMESPACE"
