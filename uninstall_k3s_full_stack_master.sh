#!/bin/bash

echo "🧨 Rancher + k3s + cert-manager 전체 제거 스크립트"
echo "⚠️ 이 작업은 마스터 노드의 모든 설정과 클러스터 노드를 삭제합니다."
read -p "계속하시겠습니까? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "⛔ 작업이 취소되었습니다."
    exit 0
fi

set +e

KUBECTL=$(command -v kubectl)
HELM=$(command -v helm)

if [ -n "$KUBECTL" ]; then
  echo "⏳ Kubernetes API 연결 확인 중..."
  for i in {1..30}; do
    $KUBECTL get nodes >/dev/null 2>&1 && break
    sleep 1
  done
fi

echo ""
echo "[1/8] 클러스터 노드 목록 삭제"
if [ -n "$KUBECTL" ]; then
  NODES=$($KUBECTL get nodes -o name 2>/dev/null)
  for node in $NODES; do
    echo "🗑️ 노드 삭제: $node"
    $KUBECTL delete "$node" --ignore-not-found=true
  done
else
  echo "⚠️ kubectl 명령어 없음, 노드 삭제 생략"
fi

echo ""
echo "[2/8] Rancher Helm 리소스 삭제"
if [ -n "$HELM" ] && $HELM list -n cattle-system | grep rancher >/dev/null 2>&1; then
    $HELM uninstall rancher -n cattle-system --timeout 60s
else
    echo "ℹ️ Rancher Helm 리소스 없음, 건너뜀"
fi

echo "[3/8] cattle-system 네임스페이스 강제 삭제"
[ -n "$KUBECTL" ] && $KUBECTL delete namespace cattle-system --grace-period=0 --force --ignore-not-found=true

echo "[4/8] cert-manager Helm 리소스 삭제"
if [ -n "$HELM" ] && $HELM list -n cert-manager | grep cert-manager >/dev/null 2>&1; then
    $HELM uninstall cert-manager -n cert-manager --timeout 60s
else
    echo "ℹ️ cert-manager Helm 리소스 없음, 건너뜀"
fi

echo "[5/8] ClusterIssuer 및 cert-manager 네임스페이스 삭제"
if [ -n "$KUBECTL" ]; then
    echo "⏳ ClusterIssuer 삭제 시도"
    $KUBECTL delete clusterissuer letsencrypt-prod --ignore-not-found=true

    if command -v jq >/dev/null 2>&1; then
        echo "🧹 ClusterIssuer finalizer 제거 (jq 사용)"
        $KUBECTL get clusterissuer letsencrypt-prod -o json 2>/dev/null \
          | jq 'del(.metadata.finalizers)' \
          | $KUBECTL replace --raw "/apis/cert-manager.io/v1/clusterissuers/letsencrypt-prod/finalize" -f - 2>/dev/null
    else
        echo "⚠️ jq 미설치: finalizer 제거 생략됨"
    fi

    echo "⏳ cert-manager 네임스페이스 강제 삭제"
    $KUBECTL delete namespace cert-manager --grace-period=0 --force --ignore-not-found=true
fi

echo "[6/8] Helm repo 제거"
[ -n "$HELM" ] && $HELM repo remove rancher-latest jetstack 2>/dev/null

echo "[7/8] k3s 클러스터 및 바이너리 제거"
[ -f /usr/local/bin/k3s-uninstall.sh ] && /usr/local/bin/k3s-uninstall.sh || echo "⚠️ k3s-uninstall.sh 없음"

echo "[8/8] 잔여 파일 정리"
rm -f /usr/local/bin/kubectl /tmp/k3s_token.txt

echo ""
echo "✅ 전체 삭제 완료! 시스템이 초기 상태로 복원되었습니다."
echo "💡 재설치를 원하시면 install_k3s_full_stack_master.sh 를 다시 실행하세요."
