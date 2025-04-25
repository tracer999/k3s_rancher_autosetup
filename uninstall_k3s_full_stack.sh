#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "😎 K3s 클러스터 전체 삭제 스크립트"
echo "1) 마스터 노드 삭제"
echo "2) 워커 노드 삭제"
read -p "선택하세요 (1 or 2): " mode

# 네임스페이스 Finalizer 제거 함수
delete_namespace_force() {
  ns="$1"
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "⚠️ [$ns] kubectl 명령어 없음 - Finalizer 제거 건너뜀"
    return
  fi

  echo "📍 [$ns] 네임스페이스 삭제 요청"
  kubectl delete ns "$ns" --ignore-not-found=true --wait=false || true
  sleep 2
  if kubectl get ns "$ns" &>/dev/null; then
    echo "⚠️ [$ns] Finalizer 제거 시도"
    kubectl get ns "$ns" -o json | jq 'del(.spec.finalizers)' > "$SCRIPT_DIR/tmp_${ns}.json"
    kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f "$SCRIPT_DIR/tmp_${ns}.json" || true
    rm -f "$SCRIPT_DIR/tmp_${ns}.json"
  fi
}

# 공통 저장소 삭제
delete_common() {
  echo "🧹 [공통] 로컬 저장소 삭제"
  sudo rm -rf /var/lib/rancher/k3s/storage || true
}

if [[ "$mode" == "1" ]]; then
  echo "🧹 마스터 노드 삭제 시작..."
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  echo "[1/11] 네임스페이스 강제 삭제"
  for ns in ingress-nginx production local; do
    delete_namespace_force "$ns"
  done

  echo "[2/11] Webhook 삭제"
  kubectl delete validatingwebhookconfigurations ingress-nginx-admission validating-webhook-configuration --ignore-not-found || true

  echo "[3/11] Helm 릴리즈 제거"
  for release in rancher cert-manager; do
    helm uninstall "$release" -n cattle-system 2>/dev/null || true
  done

  echo "[4/11] Docker 레지스트리 제거"
  docker stop registry 2>/dev/null || true
  docker rm registry 2>/dev/null || true
  sudo rm -rf /opt/registry

  echo "[5/11] Docker 설정 정리"
  REG_IP=$(cat "$SCRIPT_DIR/registry_ip" 2>/dev/null || echo "")
  if [[ -n "$REG_IP" && -f /etc/docker/daemon.json ]]; then
    sudo sed -i "/$REG_IP:5000/d" /etc/docker/daemon.json || true
    sudo systemctl restart docker || true
  fi
  rm -f "$SCRIPT_DIR/registry_ip"


  echo "[5.5/11] Docker 서비스 정지 및 클린업"
  sudo systemctl stop docker || true
  sudo systemctl disable docker || true

  echo "[5.6/11] Docker 레지스트리 및 환경 완전 삭제 (옵션)"
  read -p "⚠️ Docker 및 Containerd까지 완전히 삭제할까요? (y/n): " DELETE_DOCKER
  if [[ "$DELETE_DOCKER" == "y" ]]; then
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io || true
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /run/docker.sock || true
    echo "✅ Docker 관련 파일 완전히 삭제됨"
  else
    echo "⏭️ Docker 삭제 생략"
  fi




  echo "[6/11] 환경설정 및 유틸 제거"
  sudo sed -i '/KUBECONFIG/d' /etc/profile /etc/bash.bashrc || true
  sudo rm -f /usr/local/bin/kubectl /usr/local/bin/helm

  echo "[7/11] 서비스 중지 및 언마운트"
  #sudo systemctl stop k3s 2>/dev/null || true
  sudo systemctl stop k3s-agent 2>/dev/null || true
  sudo systemctl disable k3s 2>/dev/null || true
  sudo systemctl disable k3s-agent 2>/dev/null || true

  # 안전하게 containerd 관련 프로세스 종료
#  ps -ef | grep containerd-shim | grep -v grep | awk '{print $2}' | xargs -r sudo kill -9
#  ps -ef | grep containerd | grep -v grep | awk '{print $2}' | xargs -r sudo kill -9  


  #echo "[8/11] 설정 디렉토리 정리"
  # sudo rm -rf /etc/rancher/k3s /var/lib/rancher /var/lib/kubelet /run/k3s /run/flannel /var/lib/containerd /run/containerd

  echo "[9/11] k3s 제거"
  if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    /usr/local/bin/k3s-uninstall.sh || true
  fi

  echo "[10/11] 공통 저장소 제거"
  delete_common

  echo "[11/11] 마스터 노드 삭제 완료 🎉"

elif [[ "$mode" == "2" ]]; then
  echo "🧹 워커 노드 삭제 시작..."

  echo "[1/4] k3s-agent 제거"
  /usr/local/bin/k3s-agent-uninstall.sh || true

  echo "[2/4] 디렉토리 정리"
  sudo rm -f /etc/rancher/k3s/registries.yaml
  sudo rm -rf /etc/rancher/k3s /var/lib/rancher /var/lib/kubelet /run/k3s

  echo "[3/4] registry_ip 제거"
  rm -f "$SCRIPT_DIR/registry_ip"

  echo "[4/4] 로컬 저장소 정리"
  delete_common

  echo "✅ 워커 노드 삭제 완료"

else
  echo "❌ 잘못된 선택입니다. 1 또는 2를 입력하세요."
  exit 1
fi

echo "🎉 전체 삭제 작업 완료!"

