#!/bin/bash
set -e

# Move to deploy/redis directory relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/deploy/redis"

# ✅ Set kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🛠️ Redis Helm Chart Auto Installation Script"
echo "💡 If the 'production' namespace does not exist, it will be created."

# Get user input
read -p "Redis service name (to be used as hostname in Spring, etc.): " REDIS_HOST

# Set variables
NAMESPACE="production"
RELEASE_NAME=$REDIS_HOST
CHART_NAME="bitnami/redis"
REPO_NAME="bitnami"
REPO_URL="https://charts.bitnami.com/bitnami"

# [1] Create namespace
echo "[1/5] Attempting to create namespace '$NAMESPACE'"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# [2] Add Helm repository
echo "[2/5] Adding Helm repository"
helm repo add $REPO_NAME $REPO_URL || true
helm repo update

# [3] Generate values-redis.yaml
echo "[3/5] Generating values-redis.yaml"
cat <<EOF > values-redis.yaml
fullnameOverride: $REDIS_HOST

architecture: standalone

auth:
  enabled: true
  password: "NEWtec4075@"

master:
  service:
    type: NodePort
    nodePorts:
      redis: "31679"
  port: 6379

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 500m
EOF

# [4] Install Redis via Helm
echo "[4/5] Installing Redis..."
helm upgrade --install $RELEASE_NAME $CHART_NAME \
  --namespace $NAMESPACE \
  -f values-redis.yaml

# [5] Output result
echo ""
echo "✅ Redis installation complete!"
echo "🛰️ Connection host: <Worker Node Public IP>:31679"
echo "    Or from inside the cluster: $REDIS_HOST.$NAMESPACE.svc.cluster.local:6379"
echo ""
kubectl get svc -n $NAMESPACE

# Wait for Pod readiness
echo "⏳ Waiting for Redis Pod to become ready..."
if ! kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=$REDIS_HOST -n $NAMESPACE --timeout=90s; then
  echo "⚠️ Pod is not ready. Please check the status using the following commands:"
  echo "   kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/instance=$REDIS_HOST"
  echo "   kubectl logs -n $NAMESPACE pod/$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$REDIS_HOST -o jsonpath='{.items[0].metadata.name}')"
fi

# Display node information
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$REDIS_HOST -o jsonpath="{.items[0].metadata.name}")
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.spec.nodeName}")
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath="{.status.addresses[?(@.type==\"InternalIP\")].address}")
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.status.podIP}")

echo "📍 Redis Pod is running on node: $NODE_NAME ($NODE_IP)"
echo "🔗 Redis Pod name: $POD_NAME"
echo "🔗 Redis Pod IP: $POD_IP"
echo "🔗 Redis service name: $REDIS_HOST"
