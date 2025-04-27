#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🤩 k3s 클러스터 구성 스크립트"
echo "1) 마스터 노드 설치"
echo "2) 워커 노드 설치"
read -p "선택하세요 (1 or 2): " mode

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

if [[ "$mode" == "1" ]]; then
  echo "🛠 마스터 노드 설치 시작..."
  read -p "Rancher에서 사용할 도메인 입력 (예: rancher.sample.com): " RANCHER_DOMAIN

  echo "[1/11] 시스템 업데이트 및 패키지 설치"
  sudo apt update && sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release jq

  echo "[2/11] k3s 설치"
  curl -sfL https://get.k3s.io | sh -

  REGISTRY_IP=$(hostname -I | awk '{print $1}')
  echo "$REGISTRY_IP" > "$SCRIPT_DIR/registry_ip"

  echo "[3/11] Helm 설치"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  echo "[4/11] Kubeconfig 설정"
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' | sudo tee -a /etc/profile /etc/bash.bashrc > /dev/null
  sudo chmod +r /etc/rancher/k3s/k3s.yaml
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  
  
  echo "[5/11] 로컬 스토리지 경로 생성"
  sudo mkdir -p /var/lib/rancher/k3s/storage
  sudo chmod -R 777 /var/lib/rancher/k3s/storage

  echo "[6/11] cert-manager 설치"
  kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm install cert-manager jetstack/cert-manager --namespace cattle-system --set installCRDs=true

  echo "[7/11] Rancher 설치 (도메인: $RANCHER_DOMAIN)"
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
  helm repo update
  helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --set hostname="$RANCHER_DOMAIN" \
    --set replicas=1 \
    --set bootstrapPassword=admin

  echo "[8/11] Rancher NodePort 강제 설정"
  kubectl patch svc rancher -n cattle-system -p '{"spec": {"type": "NodePort"}}'

  echo "[9/11] production 네임스페이스 생성"
  kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

  echo "[10/11] Ingress Controller 설치"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml
  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s

  echo "[11/11] 로컬 Docker Registry 설치"
  if ! command -v docker &> /dev/null; then
    echo "🐳 Docker가 설치되지 않았습니다. 설치 진행..."

    echo "[1] Docker APT 저장소 설정"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "[2] Docker 설치"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  if ! sudo docker ps --format '{{.Names}}' | grep -q '^registry$'; then
    sudo mkdir -p /opt/registry/data
    sudo docker run -d --restart=always --name registry \
      -p 5000:5000 \
      -v /opt/registry/data:/var/lib/registry \
      registry:2
  fi

  echo "[11+] Docker insecure registry 설정"
  sudo mkdir -p /etc/docker
  cat <<EOF | sudo tee /etc/docker/daemon.json > /dev/null
{
  "insecure-registries": ["$REGISTRY_IP:5000"]
}
EOF
  sudo systemctl restart docker

  echo "[11++] 마스터 노드의 containerd 레지스트리 설정 추가"
  sudo mkdir -p /etc/rancher/k3s
  cat <<EOF | sudo tee /etc/rancher/k3s/registries.yaml > /dev/null
  mirrors:
    "$REGISTRY_IP:5000":
      endpoint:
        - "http://$REGISTRY_IP:5000"
EOF
  sudo systemctl restart k3s


  sudo apt install -y nfs-common

  echo ""
  echo "✅ Rancher 설치 완료!"
  echo "🌐 Rancher NodePort 주소: http://$REGISTRY_IP:<NodePort>"
  echo "🌐 향후 도메인 주소: https://$RANCHER_DOMAIN (install_ingress-nginx.sh로 인증서 연동)"
  echo "👤 초기 ID: admin / 비밀번호: admin"
  echo "📦 Registry: http://$REGISTRY_IP:5000"
  echo ""

  echo "🔑 워커 노드 연결 정보"
  echo "📌 마스터 IP: $REGISTRY_IP"
  echo "🔐 Join Token:"
  sudo cat /var/lib/rancher/k3s/server/node-token

elif [[ "$mode" == "2" ]]; then
  echo "🔗 워커 노드 설치 시작..."
  read -p "마스터 노드 IP: " master_ip
  read -p "Join 토큰: " token
  echo "$master_ip" > "$SCRIPT_DIR/registry_ip"

  echo "[1/5] 로컬 스토리지 생성"
  sudo mkdir -p /var/lib/rancher/k3s/storage
  sudo chmod -R 777 /var/lib/rancher/k3s/storage

  echo "[2/5] k3s-agent 설치"
  curl -sfL https://get.k3s.io | K3S_URL="https://$master_ip:6443" K3S_TOKEN="$token" sh -

  echo "[3/5] 로컬 Registry 설정"
  CONFIG_PATH="/etc/rancher/k3s/registries.yaml"
  sudo mkdir -p /etc/rancher/k3s
  cat <<EOF | sudo tee $CONFIG_PATH > /dev/null
mirrors:
  "$master_ip:5000":
    endpoint:
      - "http://$master_ip:5000"
EOF

  echo "[4/5] k3s-agent 재시작"
  if systemctl list-units --type=service | grep -q k3s-agent; then
    sudo systemctl restart k3s-agent
  fi

  echo "[5/5] 설치 완료!"

else
  echo "❌ 잘못된 선택입니다. 1 또는 2를 입력하세요."
  exit 1
fi

echo "🚀 스크립트 실행 완료"
