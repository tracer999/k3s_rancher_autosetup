
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "😎 Full K3s Cluster Removal Script"
echo "1) Remove Master Node"
echo "2) Remove Worker Node"
read -p "Choose an option (1 or 2): " mode

# Function to force delete namespace (remove finalizers)
delete_namespace_force() {
  ns="$1"
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "⚠️ [$ns] 'kubectl' not found - skipping Finalizer removal"
    return
  fi

  echo "📍 [$ns] Requesting namespace deletion"
  kubectl delete ns "$ns" --ignore-not-found=true --wait=false || true
  sleep 2
  if kubectl get ns "$ns" &>/dev/null; then
    echo "⚠️ [$ns] Attempting to remove Finalizer"
    kubectl get ns "$ns" -o json | jq 'del(.spec.finalizers)' > "$SCRIPT_DIR/tmp_${ns}.json"
    kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f "$SCRIPT_DIR/tmp_${ns}.json" || true
    rm -f "$SCRIPT_DIR/tmp_${ns}.json"
  fi
}

# Common local volume cleanup
delete_common() {
  echo "🧹 [Common] Removing local storage"
  sudo rm -rf /var/lib/rancher/k3s/storage || true
}

if [[ "$mode" == "1" ]]; then
  echo "🧹 Starting Master Node Removal..."
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  echo "[1/11] Force delete namespaces"
  for ns in ingress-nginx production local; do
    delete_namespace_force "$ns"
  done

  echo "[2/11] Delete webhooks"
  kubectl delete validatingwebhookconfigurations ingress-nginx-admission validating-webhook-configuration --ignore-not-found || true

  echo "[3/11] Uninstall Helm releases"
  for release in rancher cert-manager; do
    helm uninstall "$release" -n cattle-system 2>/dev/null || true
  done

  echo "[4/11] Remove Docker registry"
  docker stop registry 2>/dev/null || true
  docker rm registry 2>/dev/null || true
  sudo rm -rf /opt/registry

  echo "[5/11] Clean Docker daemon config"
  REG_IP=$(cat "$SCRIPT_DIR/registry_ip" 2>/dev/null || echo "")
  if [[ -n "$REG_IP" && -f /etc/docker/daemon.json ]]; then
    sudo sed -i "/$REG_IP:5000/d" /etc/docker/daemon.json || true
    sudo systemctl restart docker || true
  fi
  rm -f "$SCRIPT_DIR/registry_ip"

  echo "[5.5/11] Stop and disable Docker services"
  sudo systemctl stop docker || true
  sudo systemctl disable docker || true

  echo "[5.6/11] Optionally remove all Docker and containerd data"
  read -p "⚠️ Do you want to completely remove Docker and containerd? (y/n): " DELETE_DOCKER
  if [[ "$DELETE_DOCKER" == "y" ]]; then
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io || true
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /run/docker.sock || true
    echo "✅ Docker and related files removed"
  else
    echo "⏭️ Skipping Docker removal"
  fi

  echo "[6/11] Remove environment settings and utilities"
  sudo sed -i '/KUBECONFIG/d' /etc/profile /etc/bash.bashrc || true
  sudo rm -f /usr/local/bin/kubectl /usr/local/bin/helm

  echo "[7/11] Stop and disable K3s services"
  sudo systemctl stop k3s-agent 2>/dev/null || true
  sudo systemctl disable k3s 2>/dev/null || true
  sudo systemctl disable k3s-agent 2>/dev/null || true

  echo "[9/11] Uninstall k3s"
  if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    /usr/local/bin/k3s-uninstall.sh || true
  fi

  echo "[10/11] Remove common storage"
  delete_common

  echo "[11/11] Master Node removal completed 🎉"

elif [[ "$mode" == "2" ]]; then
  echo "🧹 Starting Worker Node Removal..."

  echo "[1/4] Uninstall k3s-agent"
  /usr/local/bin/k3s-agent-uninstall.sh || true

  echo "[2/4] Cleanup directories"
  sudo rm -f /etc/rancher/k3s/registries.yaml
  sudo rm -rf /etc/rancher/k3s /var/lib/rancher /var/lib/kubelet /run/k3s

  echo "[3/4] Remove registry_ip file"
  rm -f "$SCRIPT_DIR/registry_ip"

  echo "[4/4] Remove local storage"
  delete_common

  echo "✅ Worker Node removal completed"

else
  echo "❌ Invalid option. Please enter 1 or 2."
  exit 1
fi

echo "🎉 Full cleanup complete!"
