#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

### 사용자로부터 그룹 이름 입력
read -p "🧹 삭제할 Tomcat 그룹 이름을 입력하세요 (예: blog-tomcat): " GROUP_NAME
if [[ -z "$GROUP_NAME" ]]; then
  echo "❌ 그룹 이름은 필수입니다."
  exit 1
fi

NAMESPACE="production"

echo ""
echo "🚨 [$GROUP_NAME] Tomcat 리소스를 삭제합니다..."

### 1. Deployment 삭제
if kubectl get deployment "$GROUP_NAME" -n $NAMESPACE &>/dev/null; then
  echo "🗑 Deployment 삭제: $GROUP_NAME"
  kubectl delete deployment "$GROUP_NAME" -n $NAMESPACE
else
  echo "⚠️ Deployment [$GROUP_NAME] 없음 (이미 삭제되었을 수 있음)"
fi

### 2. Service 삭제
if kubectl get svc "$GROUP_NAME" -n $NAMESPACE &>/dev/null; then
  echo "🗑 Service 삭제: $GROUP_NAME"
  kubectl delete service "$GROUP_NAME" -n $NAMESPACE
else
  echo "⚠️ Service [$GROUP_NAME] 없음 (이미 삭제되었을 수 있음)"
fi

echo ""
echo "✅ [$GROUP_NAME] 리소스 삭제 완료!"
