#!/bin/bash
set -e

# 기본 변수
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
NAMESPACE="production"

read -p "삭제할 MySQL Helm 릴리스 이름 (예: blog-db): " RELEASE_NAME

# 릴리스 삭제
echo "\n[1/2] Helm 릴리스 '$RELEASE_NAME' 삭제 중..."
helm uninstall $RELEASE_NAME -n $NAMESPACE || {
  echo "⚠️ Helm 릴리스 '$RELEASE_NAME' 삭제 실패 또는 존재하지 않음.";
}

# ConfigMap 삭제 (initdb SQL)
echo "\n[2/2] 관련 ConfigMap 삭제 중..."
kubectl delete configmap mysql-initdb -n $NAMESPACE || {
  echo "ℹ️ ConfigMap 'mysql-initdb' 존재하지 않음.";
}

# values-mysql.yaml 파일 제거 (선택)
echo "\n🧹 values-mysql.yaml 삭제"
rm -f values-mysql.yaml

# 상태 출력
echo "\n✅ 삭제 완료. 현재 production 네임스페이스 내 서비스 목록:"
kubectl get svc -n $NAMESPACE
