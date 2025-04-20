#!/bin/bash
set -e

echo "🤩 k3s 클러스터 구성 스크립트"
echo "1) 마스터 노드 설치"
echo "2) 워커 노드 설치"
read -p "선택하세요 (1 or 2): " mode

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

if [[ "$mode" == "1" ]]; then
  echo "🛠 마스터 노드 설치 시작..."

  read -p "접속할 Rancher 도메인명 입력 (예: rancher.ydata.co.kr): " RANCHER_DOMAIN
  echo ""

  echo "[1/11] 시스템 업데이트 및 필수 패키지 설치"
  sudo apt update && sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release jq

  echo "[2/11] k3s 설치"
  curl -sfL https://get.k3s.io | sh -

  echo "[3/11] Helm 설치"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  echo "[4/11] Kubeconfig 설정"
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' | sudo tee -a /etc/profile /etc/bash.bashrc > /dev/null
  sudo chmod +r /etc/rancher/k3s/k3s.yaml

  echo "[5/11] 로컬 스토리지 경로 생성"
  sudo mkdir -p /var/lib/rancher/k3s/storage
  sudo chmod -R 777 /var/lib/rancher/k3s/storage

  echo "[6/11] cert-manager 설치"
  kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm install cert-manager jetstack/cert-manager --namespace cattle-system --set installCRDs=true

  echo "[7/11] Rancher 설치"
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
  helm repo update

  CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
  TLS_CRT="$CERT_DIR/server.all.crt.pem"
  TLS_KEY="$CERT_DIR/server.key.pem"

  if [[ -f "$TLS_CRT" && -f "$TLS_KEY" ]]; then
    echo "🔐 인증서가 존재하므로 HTTPS로 Rancher 설치합니다."
    kubectl create secret tls tls-rancher-ingress \
      --cert="$TLS_CRT" \
      --key="$TLS_KEY" \
      -n cattle-system || true

    helm install rancher rancher-latest/rancher \
      --namespace cattle-system \
      --set hostname=$RANCHER_DOMAIN \
      --set ingress.tls.source=secret \
      --set ingress.extraAnnotations."nginx\.ingress\.kubernetes\.io/backend-protocol"=HTTPS \
      --set privateCA=true \
      --set ingress.ingressClassName=nginx \
      --set replicas=1 \
      --set bootstrapPassword=admin
  else
    echo "⚠️ 인증서가 없으므로 NodePort 기반 HTTP로 설치합니다."
    helm install rancher rancher-latest/rancher \
      --namespace cattle-system \
      --set hostname=$RANCHER_DOMAIN \
      --set replicas=1 \
      --set bootstrapPassword=admin
    echo "[추가 설정 필요] install_metallb_ssl.sh로 인증서 설정 가능"
  fi

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

  echo ""
  echo "✅ Rancher 설치 완료!"
  echo "🌐 Rancher 주소: https://$RANCHER_DOMAIN 또는 http://$REGISTRY_IP:<NodePort>"
  echo "👤 ID: admin / 비밀번호: admin"
  echo "📦 Registry: http://$REGISTRY_IP:5000"

elif [[ "$mode" == "2" ]]; then
  echo "🔗 워커 노드 설치 시작..."
  read -p "마스터 노드 IP: " master_ip
  read -p "Join 토큰: " token
  echo "$master_ip" > ~/registry_ip

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

echo "✅ 스크립트 완료"
