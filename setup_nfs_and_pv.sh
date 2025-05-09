#!/bin/bash
set -e

### 1. Get user input
read -p "📂 Enter local folder path to share (e.g., /home/tracer999/k3s_rancher_autosetup/upload): " SHARE_DIR
read -p "🔖 Enter PersistentVolume name for Kubernetes (e.g., upload-pv): " PV_NAME
read -p "🗂️ Enter PersistentVolumeClaim name for Kubernetes (e.g., upload-pvc): " PVC_NAME
read -p "📦 Enter the name of the Deployment that will use this PVC (e.g., test-nfs-pod): " DEPLOY_NAME
read -p "🌐 Enter Kubernetes namespace (default: production): " NAMESPACE
NAMESPACE=${NAMESPACE:-production}

### 2. Delete existing PVC, PV, Deployment if they exist
echo "🧹 Deleting existing resources..."
kubectl delete deployment $DEPLOY_NAME -n $NAMESPACE --ignore-not-found
kubectl delete pvc $PVC_NAME -n $NAMESPACE --ignore-not-found
kubectl delete pv $PV_NAME --ignore-not-found

### 3. Check and create shared folder
if [ ! -d "$SHARE_DIR" ]; then
  echo "📂 Shared folder does not exist. Creating: $SHARE_DIR"
  sudo mkdir -p "$SHARE_DIR"
fi
sudo chmod -R 777 "$SHARE_DIR"

### 4. Install NFS server
echo "🛠️ Installing NFS server..."
sudo apt update
sudo apt install -y nfs-kernel-server

### 5. Register NFS export in /etc/exports
echo "📦 Configuring NFS export..."
EXPORT_LINE="$SHARE_DIR *(rw,sync,no_subtree_check,no_root_squash)"
if ! grep -Fxq "$EXPORT_LINE" /etc/exports; then
  echo "$EXPORT_LINE" | sudo tee -a /etc/exports
fi
sudo exportfs -a
sudo systemctl restart nfs-kernel-server

### 6. Create Kubernetes PersistentVolume and PersistentVolumeClaim
MASTER_IP=$(hostname -I | awk '{print $1}')

echo "📝 Generating PV/PVC YAML files..."
mkdir -p pv_pvc_yaml
cat <<EOF > pv_pvc_yaml/${PV_NAME}_pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $PV_NAME
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: $SHARE_DIR
    server: $MASTER_IP
EOF

cat <<EOF > pv_pvc_yaml/${PVC_NAME}_pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC_NAME
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  resources:
    requests:
      storage: 10Gi
EOF

kubectl apply -f pv_pvc_yaml/${PV_NAME}_pv.yaml
kubectl apply -f pv_pvc_yaml/${PVC_NAME}_pvc.yaml

### 8. Completion message
echo ""
echo "✅ All setup is complete!"
echo "📂 Shared folder: $SHARE_DIR"
echo "📡 NFS Server IP: $MASTER_IP"
echo "🔗 PersistentVolume name: $PV_NAME"
echo "🔗 PersistentVolumeClaim name: $PVC_NAME (namespace: $NAMESPACE)"
