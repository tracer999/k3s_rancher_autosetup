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

echo "🚨 [$GROUP_NAME] 그룹 Tomcat 리소스를 삭제합니다..."

### 1. Deployment 삭제
DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -l app=$GROUP_NAME -o jsonpath='{.items[*].metadata.name}')
for deploy in $DEPLOYMENTS; do
  echo "🗑 Deployment 삭제: $deploy"
  kubectl delete deployment "$deploy" -n $NAMESPACE
done

### 2. Service 삭제
SERVICES=$(kubectl get svc -n $NAMESPACE -l app=$GROUP_NAME -o jsonpath='{.items[*].metadata.name}')
for svc in $SERVICES; do
  echo "🗑 Service 삭제: $svc"
  kubectl delete service "$svc" -n $NAMESPACE
done

### 3. 공통 ClusterIP 서비스 삭제
if kubectl get svc "$GROUP_NAME" -n $NAMESPACE &> /dev/null; then
  echo "🗑 ClusterIP (공통 접근) 서비스 삭제: $GROUP_NAME"
  kubectl delete service "$GROUP_NAME" -n $NAMESPACE
fi

echo "✅ [$GROUP_NAME] 그룹 리소스 삭제 완료!"
