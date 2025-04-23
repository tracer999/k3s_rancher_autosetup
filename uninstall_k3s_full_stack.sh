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
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "⚠️ [$ns] kubectl 명령어가 없어 Finalizer 제거를 건너뜁니다."
    return
  fi

  echo "📍 [$ns] 비동기 삭제 요청"
  kubectl delete ns "$ns" --ignore-not-found=true --wait=false || true
  sleep 2
  if kubectl get ns "$ns" &>/dev/null; then
    echo "⚠️ [$ns] Finalizer 강제 제거 시도"
    kubectl get ns "$ns" -o json | jq 'del(.spec.finalizers)' > "$SCRIPT_DIR/tmp_${ns}.json"
    kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f "$SCRIPT_DIR/tmp_${ns}.json" || true
    rm -f "$SCRIPT_DIR/tmp_${ns}.json"
  fi
}

# 공통 로컬 저장소 정리
delete_common() {
  echo "🧹 [공통] 로컬 저장소 삭제"
  sudo rm -rf /var/lib/rancher/k3s/storage || true
}

if [[ "$mode" == "1" ]]; then
  echo "🧹 마스터 노드 삭제 시작..."
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml


  echo "[1/11] Helm 릴리즈 제거"

  if command -v helm >/dev/null 2>&1; then
    set +e
    for RELEASE in rancher cert-manager; do
      if helm list -A | grep -q "^$RELEASE[[:space:]]"; then
        helm uninstall "$RELEASE" -n cattle-system
      else
        echo "⚠️ $RELEASE 릴리즈가 존재하지 않습니다."
      fi
    done
    set -e
  else
    echo "⚠️ helm 명령어가 존재하지 않아 릴리즈 제거를 건너뜁니다."
  fi



  echo "[2/11] 네임스페이스 삭제 (비동기 + Finalizer 제거)"

  if command -v kubectl >/dev/null 2>&1; then
    namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' \
      | grep -E '^(cattle-|fleet-|local|p-|production|ingress-nginx)$')
    for ns in $namespaces; do
      delete_namespace_force "$ns"
    done
  else
    echo "⚠️ kubectl 명령어가 존재하지 않아 네임스페이스 제거를 건너뜁니다."
  fi

  echo "[3/11] Webhook 삭제"

  if command -v kubectl >/dev/null 2>&1; then
    kubectl patch validatingwebhookconfigurations ingress-nginx-admission -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl patch validatingwebhookconfigurations validating-webhook-configuration -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
    kubectl delete validatingwebhookconfigurations ingress-nginx-admission validating-webhook-configuration --ignore-not-found || true
  else
    echo "⚠️ kubectl 명령어가 없어 Webhook 삭제를 건너뜁니다."
  fi

  echo "[4/11] Ingress Controller 리소스 제거"

  if command -v kubectl >/dev/null 2>&1; then
    delete_namespace_force ingress-nginx
  else
    echo "⚠️ kubectl 명령어가 없어 ingress-nginx 리소스 제거를 건너뜁니다."
  fi

  echo "[5/11] 로컬 Docker Registry 제거"
  docker stop registry 2>/dev/null || true
  docker rm registry 2>/dev/null || true
  sudo rm -rf /opt/registry

  echo "[6/11] Docker insecure registry 설정 정리"
  REG_IP=$(cat "$SCRIPT_DIR/registry_ip" 2>/dev/null || echo "")
  if [[ -n "$REG_IP" && -f /etc/docker/daemon.json ]]; then
    sudo sed -i "/$REG_IP:5000/d" /etc/docker/daemon.json || true
    sudo systemctl restart docker || true
  fi
  rm -f "$SCRIPT_DIR/registry_ip"

  echo "[7/11] 관련 파일 및 설정 정리"
  sudo sed -i '/KUBECONFIG/d' /etc/profile /etc/bash.bashrc || true
  sudo rm -f /usr/local/bin/kubectl /usr/local/bin/helm

  echo "[7.5/11] containerd/k3s 관련 프로세스 종료 및 언마운트"
  sudo pkill -f k3s || true
  echo "7.5.2"
  sudo pkill -f containerd || true
  echo "7.5.3"
  sudo pkill -f containerd-shim || true
  sleep 2
  
  # 안전하게 언마운트 처리
  if compgen -G "/run/k3s/*" > /dev/null; then
    sudo umount -lf /run/k3s/* || true
  else
    echo "⚠️ /run/k3s/* 대상이 없어 언마운트 건너뜀"
  fi


  if compgen -G "/var/lib/kubelet/pods/*/volumes/*" > /dev/null; then
    sudo umount -lf /var/lib/kubelet/pods/*/volumes/* || true
  else
    echo "⚠️ /var/lib/kubelet/pods/*/volumes/* 대상이 없어 언마운트 건너뜀"
  fi

  echo "[8/11] 마스터 노드 설정 디렉토리 정리"
  sudo rm -rf /etc/rancher/k3s /var/lib/rancher /var/lib/kubelet /run/k3s /run/flannel

  echo "[9/11] k3s 마스터 완전 제거"
  if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    /usr/local/bin/k3s-uninstall.sh || true
  else
    echo "⚠️ k3s-uninstall.sh 가 존재하지 않아 건너뜁니다."
  fi

  echo "[10/11] 로컬 저장소 정리"
  delete_common

  echo "[11/11] 마스터 노드 삭제 완료 🎉"

elif [[ "$mode" == "2" ]]; then
  echo "🧹 워커 노드 삭제 시작..."

  echo "[1/4] k3s-agent 제거"
  /usr/local/bin/k3s-agent-uninstall.sh || true

  echo "[2/4] Registry 설정 및 디렉토리 정리"
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
