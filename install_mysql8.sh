#!/bin/bash
set -e

# Move to deploy/mysql directory relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/deploy/mysql"

# ✅ Set kubeconfig (usable with root as well)
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🛠️ MySQL8 Helm Chart Auto Installation Script"
echo "💡 If the 'production' namespace doesn't exist, it will be created."

# User input
read -p "Database name to create: " DB_NAME
read -p "Database username: " DB_USER
read -s -p "Database password: " DB_PASSWORD
echo ""
read -p "MySQL service name (used as host in Spring): " DB_HOST

# Variable setup
NAMESPACE="production"
RELEASE_NAME=$DB_HOST
CHART_NAME="bitnami/mysql"
REPO_NAME="bitnami"
REPO_URL="https://charts.bitnami.com/bitnami"
INIT_SQL_PATH="./init-sql/database_dump.sql"

# [1] Create namespace
echo "[1/6] Attempting to create namespace '$NAMESPACE'"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# [2] Delete and recreate ConfigMap
echo "[2/6] Recreating ConfigMap from initial SQL (database_dump.sql)"
kubectl delete configmap mysql-initdb -n $NAMESPACE --ignore-not-found
if [ ! -f "$INIT_SQL_PATH" ]; then
  echo "❌ File not found: $INIT_SQL_PATH"
  echo "   Current working directory: $(pwd)"
  exit 1
fi
kubectl create configmap mysql-initdb \
  --from-file=init.sql=$INIT_SQL_PATH \
  -n $NAMESPACE

# [3] Add Helm repo
echo "[3/6] Registering Helm repository"
helm repo add $REPO_NAME $REPO_URL || true
helm repo update

# [4] Create values-mysql.yaml
echo "[4/6] Generating values-mysql.yaml"
cat <<EOF > values-mysql.yaml
fullnameOverride: $DB_HOST

auth:
  rootPassword: rootpassword
  username: $DB_USER
  password: $DB_PASSWORD
  database: $DB_NAME
  authenticationPlugin: mysql_native_password

primary:
  service:
    type: NodePort
    nodePorts:
      mysql: 31060
  port: 3306

  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 768Mi
      cpu: 750m

initdbScriptsConfigMap: mysql-initdb
EOF

# [5] Install Helm Chart
echo "[5/6] Installing MySQL8..."
helm upgrade --install $RELEASE_NAME $CHART_NAME \
  --namespace $NAMESPACE \
  -f values-mysql.yaml

# [6] Print result
echo ""
echo "✅ MySQL8 installation complete!"
echo "📛 Database name: $DB_NAME"
echo "👤 User: $DB_USER"
echo "🔐 Password: $DB_PASSWORD"
echo "🛰️ Connection host: <Worker Node Public IP>:31060"
echo "     Or internally: $DB_HOST.$NAMESPACE.svc.cluster.local:3306"
echo ""
kubectl get svc -n $NAMESPACE

# [7] Wait for pod to be ready
echo "⏳ Waiting for MySQL Pod to become ready..."
if ! kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=$DB_HOST -n $NAMESPACE --timeout=90s; then
  echo "⚠️ Pod is not ready. Check the status with the commands below:"
  echo "   kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/instance=$DB_HOST"
  echo "   kubectl logs -n $NAMESPACE pod/$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$DB_HOST -o jsonpath='{.items[0].metadata.name}')"
fi

# [8] Show node info
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$DB_HOST -o jsonpath="{.items[0].metadata.name}")
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.spec.nodeName}")
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath="{.status.addresses[?(@.type==\"InternalIP\")].address}")
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.status.podIP}")

echo "📍 MySQL Pod is running on node: $NODE_NAME ($NODE_IP)"
echo "🔗 MySQL Pod name: $POD_NAME"
echo "🔗 MySQL Pod IP: $POD_IP"
echo "🔗 MySQL Service name: $DB_HOST"
