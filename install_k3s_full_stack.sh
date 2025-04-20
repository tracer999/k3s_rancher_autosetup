#!/bin/bash
set -e

echo "🤩 k3s 클러스터 구성 스크립트"
echo "1) 마스터 노드 설치"
echo "2) 워커 노드 설치"
read -p "선택하세요 (1 or 2): " mode

if [[ "$mode" == "1" ]]; then
  echo "🛠 마스터 노드 설치 시작..."

  echo "[1/9] 시스템 업데이트 및 필요 패키지 설치"
  sudo apt update && sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release jq

  echo "[2/9] k3s 설치"
  curl -sfL https://get.k3s.io | sh -

  echo "[3/9] Helm 설치"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  echo "[4/9] Kubeconfig 설정"
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' | sudo tee -a /etc/profile /etc/bash.bashrc > /dev/null
  sudo chmod +r /etc/rancher/k3s/k3s.yaml

  echo "[5/9] 로컬 스토리지 경로 생성"
  sudo mkdir -p /var/lib/rancher/k3s/storage
  sudo chmod -R 777 /var/lib/rancher/k3s/storage

  echo "[6/9] cert-manager 설치"
  kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm install cert-manager jetstack/cert-manager --namespace cattle-system --set installCRDs=true

  echo "[7/9] Rancher 설치"
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
  helm repo update
  helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --set hostname=rancher.localhost \
    --set replicas=1 \
    --set bootstrapPassword=admin

  echo "[8/9] Rancher NodePort 변경"
  kubectl patch svc rancher -n cattle-system -p '{"spec": {"type": "NodePort"}}'

  echo "[9/9] production namespace 생성"
  kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

  #### 로컬 Docker Registry 구축 ####
  echo "📆 로컬 Docker 레지스트리 구축"

  if ! command -v docker &> /dev/null; then
    echo "🐳 Docker가 설치되지 않았습니다. 설치 진행..."
    sudo apt install -y ca-certificates curl gnupg lsb-release jq
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  if ! docker ps --format '{{.Names}}' | grep -q '^registry$'; then
    sudo mkdir -p /opt/registry/data
    docker run -d --restart=always --name registry \
      -p 5000:5000 \
      -v /opt/registry/data:/var/lib/registry \
      registry:2
  fi

  REGISTRY_IP=$(hostname -I | awk '{print $1}')
  echo "$REGISTRY_IP" > ~/registry_ip

  echo "🚀 파이드 정보"
  echo "➡ Rancher UI: http://$REGISTRY_IP:<NodePort>"
  echo "➡ Registry: http://$REGISTRY_IP:5000"
  echo "➡ docker tag my-image $REGISTRY_IP:5000/my-image"
  echo "➡ docker push $REGISTRY_IP:5000/my-image"
  echo ""
  echo "🌐 마스터 노드 정보"
  echo "📌 마스터 IP: $REGISTRY_IP"
  echo "🔑 Join Token:"
  sudo cat /var/lib/rancher/k3s/server/node-token

elif [[ "$mode" == "2" ]]; then
  echo "🔗 워커 노드 설치 시작..."

  read -p "마스터 노드의 IP 입력: " master_ip
  read -p "Join 토큰 입력: " token

  echo "[1/5] 로컬 스토리지 경로 생성"
  sudo mkdir -p /var/lib/rancher/k3s/storage
  sudo chmod -R 777 /var/lib/rancher/k3s/storage

  echo "[2/5] k3s 에이전트 설치"
  curl -sfL https://get.k3s.io | K3S_URL="https://$master_ip:6443" K3S_TOKEN="$token" sh -

  echo "[3/5] 레지스트리 미러 설정"
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
