#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "📦 현재 설치된 Helm 릴리스 목록 (모든 네임스페이스):"
helm list -A

echo ""
read -p "🧭 삭제할 릴리스 이름을 입력하세요: " RELEASE_NAME
read -p "📂 릴리스가 설치된 네임스페이스를 입력하세요: " RELEASE_NS

if [ -z "$RELEASE_NAME" ] || [ -z "$RELEASE_NS" ]; then
  echo "❌ 릴리스 이름과 네임스페이스는 모두 입력해야 합니다."
  exit 1
fi

# 릴리스 존재 여부 확인
if ! helm status "$RELEASE_NAME" -n "$RELEASE_NS" > /dev/null 2>&1; then
  echo "❌ 릴리스 '$RELEASE_NAME' 가 네임스페이스 '$RELEASE_NS' 에 존재하지 않습니다."
  exit 1
fi

echo ""
read -p "⚠️ 정말로 Helm 릴리스 '$RELEASE_NAME' 을 삭제하시겠습니까? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "🚫 삭제를 취소했습니다."
  exit 0
fi

echo ""
echo "🧨 Helm 릴리스 삭제 중..."
helm uninstall "$RELEASE_NAME" -n "$RELEASE_NS"

echo ""
echo "✅ Helm 릴리스 '$RELEASE_NAME' 삭제 완료!"

# PVC 확인 및 삭제
echo ""
echo "🧹 PVC 자동 정리 중 (라벨: app.kubernetes.io/instance=$RELEASE_NAME)..."
kubectl delete pvc -n "$RELEASE_NS" -l app.kubernetes.io/instance="$RELEASE_NAME" || {
  echo "⚠️ PVC 삭제 중 오류가 발생했거나 존재하지 않습니다."
}

echo ""
echo "✅ 정리 완료!"
