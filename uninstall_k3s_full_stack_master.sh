#!/bin/bash

echo "🧨 Rancher + k3s + cert-manager 전체 제거 스크립트 (v6.2 - Quiet & Non-blocking)"
echo "⚠️ 이 작업은 마스터 노드의 모든 설정과 클러스터 노드를 제거합니다."
read -p "계속하시겠습니까? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "⛔️ 작업이 취소되었습니다."
    exit 0
fi

set +e

KUBECTL=$(command -v kubectl)
HELM=$(command -v helm)

# 0. Kubernetes API 연결 확인
if [ -n "$KUBECTL" ]; then
  echo "⏳ Kubernetes API 연결 확인 중..."
  for i in {1..30}; do
    $KUBECTL get nodes >/dev/null 2>&1 && break
    sleep 1
  done
fi

# 1. 클러스터 노드 제거
echo -e "\n[1/8] 클러스터 노드 목록 제거"
if [ -n "$KUBECTL" ]; then
  NODES=$($KUBECTL get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  for NODE in $NODES; do
    echo "🗑️ 노드 제거: $NODE"
    $KUBECTL delete node "$NODE" --ignore-not-found=true --timeout=15s >/dev/null 2>&1
  done
fi

# 2. Rancher 삭제
echo -e "\n[2/8] Rancher Helm 리소스 삭제"
if [ -n "$HELM" ] && $HELM list -n cattle-system | grep rancher >/dev/null 2>&1; then
  $HELM uninstall rancher -n cattle-system --timeout 30s >/dev/null 2>&1
else
  echo "ℹ️ Rancher 리소스 없음"
fi

# 3. cattle-system 삭제
echo -e "\n[3/8] cattle-system 네임스페이스 강제 삭제"
$KUBECTL delete namespace cattle-system --grace-period=0 --force --timeout=15s --wait=false >/dev/null 2>&1

# 4. cert-manager Helm 삭제
echo -e "\n[4/8] cert-manager Helm 리소스 삭제"
if [ -n "$HELM" ] && $HELM list -n cert-manager | grep cert-manager >/dev/null 2>&1; then
  $HELM uninstall cert-manager -n cert-manager --timeout 30s >/dev/null 2>&1
else
  echo "ℹ️ cert-manager 리소스 없음"
fi

# 5. ClusterIssuer 삭제 및 cert-manager 네임스페이스 제거
echo -e "\n[5/8] ClusterIssuer + cert-manager 네임스페이스 삭제"
$KUBECTL delete clusterissuer letsencrypt-prod --ignore-not-found=true >/dev/null 2>&1
if command -v jq >/dev/null 2>&1; then
  $KUBECTL get clusterissuer letsencrypt-prod -o json 2>/dev/null | \
    jq 'del(.metadata.finalizers)' | \
    $KUBECTL replace --raw "/apis/cert-manager.io/v1/clusterissuers/letsencrypt-prod/finalize" -f - >/dev/null 2>&1
fi
$KUBECTL delete namespace cert-manager --grace-period=0 --force --timeout=15s --wait=false >/dev/null 2>&1

# 6. Helm repo 제거
echo -e "\n[6/8] Helm 리포지터리 제거"
$HELM repo remove rancher-latest >/dev/null 2>&1
$HELM repo remove jetstack >/dev/null 2>&1

# 7. k3s 자체 제거
echo -e "\n[7/8] k3s 클러스터 및 바이너리 제거"
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
  /usr/local/bin/k3s-uninstall.sh >/dev/null 2>&1
else
  echo "ℹ️ k3s-uninstall.sh 없음 (이미 제거됨)"
fi

# 8. 기타 정리
echo -e "\n[8/8] 불필요한 파일 정리"
rm -f /usr/local/bin/kubectl
rm -f /tmp/k3s_token.txt

echo ""
echo "✅ 전체 삭제 완료! 시스템이 초기 상태로 복원되었습니다."
echo "💡 재설치를 원하시면 install_k3s_full_stack_master.sh 를 다시 실행하세요."
