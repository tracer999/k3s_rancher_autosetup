#!/bin/bash

echo "🧨 Rancher + k3s + cert-manager 전체 제거 스크립트 (v4)"
echo "⚠️ 이 작업은 마스터 노드의 모든 설정을 삭제합니다. 계속하시겠습니까? (y/n)"
read -r confirm
if [[ "$confirm" != "y" ]]; then
    echo "⛔ 작업이 취소되었습니다."
    exit 0
fi

set +e  # 오류가 발생해도 계속 실행

# 경로 확인
KUBECTL=$(command -v kubectl)
HELM=$(command -v helm)

# 1. kubectl 연결 대기
if [ -n "$KUBECTL" ]; then
  echo "⏳ Kubernetes API 서버 연결 대기 중 (최대 30초)..."
  for i in {1..30}; do
    $KUBECTL get nodes >/dev/null 2>&1 && break
    sleep 1
  done
fi

echo ""
echo "[1/7] Rancher Helm 리소스 삭제"
if [ -n "$HELM" ] && $HELM list -n cattle-system | grep rancher >/dev/null 2>&1; then
    $HELM uninstall rancher -n cattle-system --timeout 60s
else
    echo "ℹ️ Rancher Helm 리소스 없음, 건너뜀"
fi

echo "[2/7] cattle-system 네임스페이스 강제 삭제"
if [ -n "$KUBECTL" ]; then
    $KUBECTL delete namespace cattle-system --grace-period=0 --force --ignore-not-found=true
else
    echo "⚠️ kubectl 명령어 없음, cattle-system 삭제 생략"
fi

echo "[3/7] cert-manager Helm 리소스 삭제"
if [ -n "$HELM" ] && $HELM list -n cert-manager | grep cert-manager >/dev/null 2>&1; then
    $HELM uninstall cert-manager -n cert-manager --timeout 60s
else
    echo "ℹ️ cert-manager Helm 리소스 없음, 건너뜀"
fi

echo "[4/7] ClusterIssuer 및 cert-manager 네임스페이스 삭제"
if [ -n "$KUBECTL" ]; then
    echo "⏳ ClusterIssuer 삭제 시도"
    $KUBECTL delete clusterissuer letsencrypt-prod --ignore-not-found=true

    if command -v jq >/dev/null 2>&1; then
        echo "🧹 ClusterIssuer finalizer 제거 (jq 사용)"
        $KUBECTL get clusterissuer letsencrypt-prod -o json 2>/dev/null \
          | jq 'del(.metadata.finalizers)' \
          | $KUBECTL replace --raw "/apis/cert-manager.io/v1/clusterissuers/letsencrypt-prod/finalize" -f - 2>/dev/null
    else
        echo "⚠️ jq가 설치되어 있지 않아 finalizer 제거 생략"
    fi

    echo "⏳ cert-manager 네임스페이스 강제 삭제"
    $KUBECTL delete namespace cert-manager --grace-period=0 --force --ignore-not-found=true
else
    echo "⚠️ kubectl 명령어 없음, cert-manager 삭제 생략"
fi

echo "[5/7] Helm repo 제거"
if [ -n "$HELM" ]; then
    $HELM repo remove rancher-latest 2>/dev/null
    $HELM repo remove jetstack 2>/dev/null
fi

echo "[6/7] k3s 클러스터 및 바이너리 제거"
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    /usr/local/bin/k3s-uninstall.sh
else
    echo "⚠️ k3s-uninstall.sh 스크립트 없음 (이미 제거되었을 수 있음)"
fi

echo "[7/7] 불필요한 파일 정리"
rm -f /usr/local/bin/kubectl
rm -f /tmp/k3s_token.txt

echo ""
echo "✅ 전체 삭제 완료! 시스템이 초기 상태로 복원되었습니다."
echo "💡 재설치를 원하시면 install_k3s_full_stack_master.sh 를 다시 실행하세요."
