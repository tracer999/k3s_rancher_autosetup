#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# 1. 네임스페이스 목록 출력
echo "🔎 현재 존재하는 네임스페이스 목록:"
kubectl get namespaces -o custom-columns=NAME:.metadata.name --no-headers
echo ""
read -p "📦 삭제 대상 네임스페이스를 입력하세요: " TARGET_NS

if [ -z "$TARGET_NS" ]; then
  echo "❌ 네임스페이스를 입력해야 합니다."
  exit 1
fi

# 2. 리소스 출력
echo ""
echo "📋 [$TARGET_NS] 안의 Deployment 목록:"
kubectl get deployments -n "$TARGET_NS" || echo "(Deployment 없음)"
echo ""
echo "📋 [$TARGET_NS] 안의 Service 목록:"
kubectl get services -n "$TARGET_NS" || echo "(Service 없음)"
echo ""
echo "📋 [$TARGET_NS] 안의 Pod 목록:"
kubectl get pods -n "$TARGET_NS" || echo "(Pod 없음)"
echo ""

# 3. 삭제할 리소스 이름 입력
read -p "🗑 삭제할 리소스 이름을 입력하세요 (예: front-tomcat): " TARGET_NAME

if [ -z "$TARGET_NAME" ]; then
  echo "❌ 리소스 이름을 입력해야 합니다."
  exit 1
fi

# 4. 시스템 보호 예외 처리
if [[ "$TARGET_NAME" == "kubernetes" ]]; then
  echo "❌ 시스템 필수 서비스 'kubernetes'는 삭제할 수 없습니다."
  exit 1
fi

# 5. 리소스 삭제
echo ""
echo "🧨 [$TARGET_NS] 네임스페이스에서 $TARGET_NAME 관련 리소스 삭제 중..."
kubectl delete deployment "$TARGET_NAME" -n "$TARGET_NS" --ignore-not-found
kubectl delete service "$TARGET_NAME" -n "$TARGET_NS" --ignore-not-found
kubectl delete pod -l app="$TARGET_NAME" -n "$TARGET_NS" --ignore-not-found

# 6. 삭제 후 상태 출력
echo ""
echo "✅ 삭제 완료! [$TARGET_NS] 네임스페이스 현재 상태:"
echo ""
kubectl get deployments -n "$TARGET_NS" || true
kubectl get services -n "$TARGET_NS" || true
kubectl get pods -n "$TARGET_NS" || true
