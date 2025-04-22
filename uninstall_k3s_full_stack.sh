#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "😎 k3s 클러스터 전체 삭제 스크립트"
echo "1) 마스터 노드 삭제"
echo "2) 워커 노드 삭제"
read -p "선택하세요 (1 or 2): " mode

# 네임스페이스 강제 삭제 함수
delete_namespace_force() {
  ns="$1"
  echo "📍 [$ns] 비동기 삭제 요청"
  kubectl delete ns "$ns" --ignore-not-found=true --wait=false || true
  sleep 2  # 삭제 API 요청 반영 대기

  if kubectl get ns "$ns" &>/dev/null; then
    echo "⚠️ [$ns] Finalizer 강제 제거 시도"
    kubectl get ns "$ns" -o json | jq 'del(.spec.finalizers)' > "$SCRIPT_DIR/tmp_${ns}.json"
    kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f "$SCRIPT_DIR/tmp_${ns}.json" || true
    rm -f "$SCRIPT_DIR/tmp_${ns}.json"
  fi
}

# 공통 삭제
delete_common() {
  echo "🧹 [공통] 로컬 저장소 삭제"
  sudo rm -rf /var/lib/rancher/k3s/storage || true
}

if [[ "$mode" == "1" ]]; then
  echo "🧹 마스터 노드 삭제 시작..."
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  echo "[1/10] Helm 릴리즈 제거"
  helm uninstall rancher -n cattle-system 2>/dev/null || true
  helm uninstall cert-manager -n cattle-system 2>/dev/null || true

  echo "[2/10] 네임스페이스 삭제 (비동기 + Finalizer 제거)"
  namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -E '^(cattle-|fleet-|local|p-|production|ingress-nginx)$')

  for ns in $namespaces; do
    delete_namespace_force "$ns"
  done

  echo "[3/10] Webhook 삭제"
  kubectl patch validatingwebhookconfigurations ingress-nginx-admission -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl patch validatingwebhookconfigurations validating-webhook-configuration -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
  kubectl delete validatingwebhookconfigurations ingress-nginx-admission validating-webhook-configuration --ignore-not-found || true

  echo "[4/10] Ingress Controller 리소스 제거"
  kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml \
    --ignore-not-found=true --timeout=30s || true

  echo "[5/10] k3s 마스터 제거"
  /usr/local/bin/k3s-uninstall.sh || true

  echo "[6/10] 관련 디렉터리 정리"
  sudo rm -rf /etc/rancher/k3s /var/lib/rancher /opt/registry/data
  sudo sed -i '/KUBECONFIG/d' /etc/profile /etc/bash.bashrc || true
  sudo rm -f /usr/local/bin/kubectl /usr/local/bin/helm

  echo "[7/10] 로컬 Docker Registry 제거"
  docker stop registry 2>/dev/null || true
  docker rm registry 2>/dev/null || true

  echo "[8/10] Docker insecure registry 설정 정리"
  REG_IP=$(cat "$SCRIPT_DIR/registry_ip" 2>/dev/null || echo "")
  if [[ -n "$REG_IP" && -f /etc/docker/daemon.json ]]; then
    sudo sed -i "/$REG_IP:5000/d" /etc/docker/daemon.json || true
    sudo systemctl restart docker || true
  fi
  rm -f "$SCRIPT_DIR/registry_ip"

  echo "[9/10] 로컬 저장소 정리"
  delete_common

  echo "[10/10] 마스터 노드 삭제 완료 🎉"

elif [[ "$mode" == "2" ]]; then
  echo "🧹 워커 노드 삭제 시작..."

  echo "[1/4] k3s-agent 제거"
  /usr/local/bin/k3s-agent-uninstall.sh || true

  echo "[2/4] 로컬 Registry 설정 제거"
  sudo rm -f /etc/rancher/k3s/registries.yaml
  sudo rm -rf /etc/rancher/k3s

  echo "[3/4] IP 정보 파일 제거"
  rm -f "$SCRIPT_DIR/registry_ip"

  echo "[4/4] 로컬 저장소 제거"
  delete_common

  echo "✅ 워커 노드 삭제 완료"

else
  echo "❌ 잘못된 선택입니다. 1 또는 2를 입력하세요."
  exit 1
fi

echo "🎉 전체 삭제 작업 완료!"
