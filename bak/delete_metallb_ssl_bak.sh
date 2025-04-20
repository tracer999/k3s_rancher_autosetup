#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

read -p "삭제할 Ingress 외부 포트 (예: 443): " EXTERNAL_PORT
if [[ -z "$EXTERNAL_PORT" ]]; then
  echo "❌ 포트 번호는 필수입니다."
  exit 1
fi

echo "🚨 Ingress 및 TLS Secret 삭제 중 (포트: $EXTERNAL_PORT)..."

kubectl delete ingress ingress-$EXTERNAL_PORT -n production --ignore-not-found
kubectl delete secret tls-$EXTERNAL_PORT -n production --ignore-not-found

echo "✅ 삭제 완료: ingress-$EXTERNAL_PORT 및 tls-$EXTERNAL_PORT"
