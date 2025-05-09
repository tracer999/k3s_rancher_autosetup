#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

### 🛠 Set base variables
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$BASE_DIR/deploy/tomcat10"
REGISTRY_IP_FILE="$BASE_DIR/registry_ip"
DEPLOY_YAML="$DEPLOY_DIR/tomcat10.yaml"
NAMESPACE="production"

### [1] User input
echo "🌐 Tomcat Instance Deployment Script (for k3s)"

read -p "🌟 Enter service name for external access (e.g., blog-tomcat): " GROUP_NAME
if [[ -z "$GROUP_NAME" ]]; then
  echo "❌ Service name is required."
  exit 1
fi

read -p "🔁 Number of Tomcat instances to deploy (e.g., 2): " REPLICA_COUNT
REPLICA_COUNT=${REPLICA_COUNT:-2}

### [1-1] Optional: Mount additional PVC
echo "📦 Current PVCs in the '$NAMESPACE' namespace:"
kubectl get pvc -n $NAMESPACE
echo ""
read -p "📂 Enter the name of the PVC to mount (press Enter to skip): " PVC_NAME
PVC_NAME=${PVC_NAME:-}

### [2] Get registry IP
if [ ! -f "$REGISTRY_IP_FILE" ]; then
  echo "❌ registry_ip file not found: $REGISTRY_IP_FILE"
  exit 1
fi
REGISTRY_IP=$(cat "$REGISTRY_IP_FILE")
IMAGE_TAG="$GROUP_NAME:latest"
FULL_IMAGE_TAG="$REGISTRY_IP:5000/$IMAGE_TAG"

### [3] Build and push Docker image
echo "🔨 Building Tomcat image: $FULL_IMAGE_TAG"
docker build -t "$FULL_IMAGE_TAG" -f "$DEPLOY_DIR/Dockerfile" "$DEPLOY_DIR"
echo "📤 Pushing image..."
docker push "$FULL_IMAGE_TAG"

### [4] Remove old YAML and create new one
if [ -f "$DEPLOY_YAML" ]; then
  echo "🗑 Removing old deployment YAML: $DEPLOY_YAML"
  rm -f "$DEPLOY_YAML"
fi

echo "📝 Generating new deployment YAML: $DEPLOY_YAML"

cat <<EOF > "$DEPLOY_YAML"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $GROUP_NAME
  namespace: $NAMESPACE
  labels:
    app: $GROUP_NAME
spec:
  replicas: $REPLICA_COUNT
  selector:
    matchLabels:
      app: $GROUP_NAME
  template:
    metadata:
      labels:
        app: $GROUP_NAME
    spec:
      containers:
      - name: tomcat
        image: $FULL_IMAGE_TAG
        ports:
        - containerPort: 8080
EOF

if [[ -n "$PVC_NAME" ]]; then
cat <<EOF >> "$DEPLOY_YAML"
        volumeMounts:
        - name: upload-volume
          mountPath: /blog_demo/uploads
EOF
fi

cat <<EOF >> "$DEPLOY_YAML"
      volumes:
EOF

if [[ -n "$PVC_NAME" ]]; then
cat <<EOF >> "$DEPLOY_YAML"
      - name: upload-volume
        persistentVolumeClaim:
          claimName: $PVC_NAME
EOF
fi

cat <<EOF >> "$DEPLOY_YAML"
---
apiVersion: v1
kind: Service
metadata:
  name: $GROUP_NAME
  namespace: $NAMESPACE
spec:
  type: NodePort
  selector:
    app: $GROUP_NAME
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 31808
EOF

### [5] Delete existing resources
echo "🧹 Deleting existing resources..."
kubectl delete deployment "$GROUP_NAME" -n "$NAMESPACE" --ignore-not-found
kubectl delete service "$GROUP_NAME" -n "$NAMESPACE" --ignore-not-found

### [6] Deploy using YAML
echo "🚀 Starting deployment using YAML..."
kubectl apply -n "$NAMESPACE" -f "$DEPLOY_YAML"

### [7] Output result
echo ""
echo "✅ [$GROUP_NAME] Tomcat deployed with $REPLICA_COUNT instance(s)!"
echo "📁 Deployment YAML location: $DEPLOY_YAML"
if [[ -n "$PVC_NAME" ]]; then
  echo "📂 Additional mounted PVC: $PVC_NAME → /blog_demo/uploads"
else
  echo "📂 No additional PVC mounted"
fi
echo "🌐 Internal access: http://$GROUP_NAME.$NAMESPACE.svc.cluster.local:8080"
echo "🌍 External access: kubectl get svc -n $NAMESPACE $GROUP_NAME"
