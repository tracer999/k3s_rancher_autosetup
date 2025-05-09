#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🤩 K3s Cluster Setup Script"
echo "1) Install Master Node"
echo "2) Install Worker Node"
read -p "Choose an option (1 or 2): " mode

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

if [[ "$mode" == "1" ]]; then
  echo "🛠 Starting Master Node Installation..."
  read -p "Enter the domain name for Rancher (e.g., rancher.example.com): " RANCHER_DOMAIN

  echo "[1/11] Updating system and installing packages"
  sudo apt update && sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release jq

  echo "[2/11] Installing k3s"
  curl -sfL https://get.k3s.io | sh -

  REGISTRY_IP=$(hostname -I | awk '{print $1}')
  echo "$REGISTRY_IP" > "$SCRIPT_DIR/registry_ip"

  echo "[3/11] Installing Helm"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  echo "[4/11] Setting up kubeconfig"
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' | sudo tee -a /etc/profile /etc/bash.bashrc > /dev/null
  sudo chmod +r /etc/rancher/k3s/k3s.yaml
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  echo "[5/11] Creating local storage path"
  sudo mkdir -p /var/lib/rancher/k3s/storage
  sudo chmod -R 777 /var/lib/rancher/k3s/storage

  echo "[6/11] Installing cert-manager"
  kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm install cert-manager jetstack/cert-manager --namespace cattle-system --set installCRDs=true

  echo "[7/11] Installing Rancher (domain: $RANCHER_DOMAIN)"
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
  helm repo update
  helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --set hostname="$RANCHER_DOMAIN" \
    --set replicas=1 \
    --set bootstrapPassword=admin

  echo "[8/11] Forcing Rancher NodePort configuration"
  kubectl patch svc rancher -n cattle-system -p '{"spec": {"type": "NodePort"}}'

  echo "[9/11] Creating 'production' namespace"
  kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

  echo "[10/11] Installing Ingress Controller via Helm"
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update

  helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace \
    --set controller.config.proxy-body-size="50m" \
    --set controller.enableModsecurity=false \
    --set controller.enableOWASPModSecurity=false

  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s

  echo "[11/11] Installing local Docker Registry"
  if ! command -v docker &> /dev/null; then
    echo "🐳 Docker not found. Installing..."

    echo "[1] Setting up Docker APT repository"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "[2] Installing Docker"
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

  echo "[11+] Configuring Docker insecure registry"
  sudo mkdir -p /etc/docker
  cat <<EOF | sudo tee /etc/docker/daemon.json > /dev/null
{
  "insecure-registries": ["$REGISTRY_IP:5000"]
}
EOF
  sudo systemctl restart docker

  echo "[11++] Adding containerd registry config for Master Node"
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
  echo "✅ Rancher installation complete!"
  echo "🌐 Rancher NodePort address: http://$REGISTRY_IP:<NodePort>"
  echo "🌐 Domain address: https://$RANCHER_DOMAIN (use install_ingress-nginx.sh to enable HTTPS)"
  echo "👤 Default ID: admin / Password: admin"
  echo "📦 Registry: http://$REGISTRY_IP:5000"
  echo ""

  echo "🔑 Worker Node Join Info"
  echo "📌 Master IP: $REGISTRY_IP"
  echo "🔐 Join Token:"
  sudo cat /var/lib/rancher/k3s/server/node-token

elif [[ "$mode" == "2" ]]; then
  echo "🔗 Starting Worker Node Installation..."
  read -p "Master Node IP: " master_ip
  read -p "Join Token: " token
  echo "$master_ip" > "$SCRIPT_DIR/registry_ip"

  echo "[1/5] Creating local storage path"
  sudo mkdir -p /var/lib/rancher/k3s/storage
  sudo chmod -R 777 /var/lib/rancher/k3s/storage

  echo "[2/5] Installing k3s-agent"
  curl -sfL https://get.k3s.io | K3S_URL="https://$master_ip:6443" K3S_TOKEN="$token" sh -

  echo "[3/5] Configuring local Docker Registry"
  CONFIG_PATH="/etc/rancher/k3s/registries.yaml"
  sudo mkdir -p /etc/rancher/k3s
  cat <<EOF | sudo tee $CONFIG_PATH > /dev/null
mirrors:
  "$master_ip:5000":
    endpoint:
      - "http://$master_ip:5000"
EOF

  echo "[4/5] Restarting k3s-agent"
  if systemctl list-units --type=service | grep -q k3s-agent; then
    sudo systemctl restart k3s-agent
  fi

  echo "[5/5] Installation complete!"

else
  echo "❌ Invalid option. Please enter 1 or 2."
  exit 1
fi

echo "🚀 Script execution complete"
