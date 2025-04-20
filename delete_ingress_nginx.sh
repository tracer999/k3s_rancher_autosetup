#!/bin/bash
set -e

NAMESPACE="production"
RELEASE_NAME="ingress-nginx"
INGRESS_NAME="nginx-proxy"
TLS_SECRET_NAME="nginx-tls-secret"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🚨 Ingress Nginx 관련 리소스를 삭제합니다..."

# Ingress 삭제
echo "🗑 Ingress 리소스 삭제..."
kubectl delete ingress $INGRESS_NAME -n $NAMESPACE --ignore-not-found

# TLS Secret 삭제
echo "🗑 TLS Secret 삭제..."
kubectl delete secret $TLS_SECRET_NAME -n $NAMESPACE --ignore-not-found

# Helm 릴리스 삭제
echo "🗑 Helm 릴리스 '$RELEASE_NAME' 삭제..."
helm uninstall $RELEASE_NAME -n $NAMESPACE || true

# Ingress 관련 Pod 확인 및 삭제
echo "🧹 관련 Pod 확인..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=ingress-nginx

echo "✅ 삭제 완료!"
