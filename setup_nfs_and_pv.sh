#!/bin/bash
set -e

### 1. 사용자 입력 받기
read -p "📂 공유할 로컬 폴더 경로 입력 (예: /home/tracer999/k3s_rancher_autosetup/upload): " SHARE_DIR
read -p "🔖 Kubernetes에서 사용할 PersistentVolume 이름 입력 (예: upload-pv): " PV_NAME
read -p "🗂️ Kubernetes에서 사용할 PersistentVolumeClaim 이름 입력 (예: upload-pvc): " PVC_NAME
read -p "📦 이 PVC를 사용할 Deployment 이름 입력 (예: test-nfs-pod): " DEPLOY_NAME
read -p "🌐 Kubernetes 네임스페이스 입력 (기본: production): " NAMESPACE
NAMESPACE=${NAMESPACE:-production}

### 2. 기존 PVC, PV, Deployment 삭제 (있으면)
echo "🧹 기존 리소스 삭제 중..."
kubectl delete deployment $DEPLOY_NAME -n $NAMESPACE --ignore-not-found
kubectl delete pvc $PVC_NAME -n $NAMESPACE --ignore-not-found
kubectl delete pv $PV_NAME --ignore-not-found

### 3. 공유 폴더 확인 및 생성
if [ ! -d "$SHARE_DIR" ]; then
  echo "📂 공유 폴더가 존재하지 않습니다. 생성합니다: $SHARE_DIR"
  sudo mkdir -p "$SHARE_DIR"
fi
sudo chmod -R 777 "$SHARE_DIR"

### 4. NFS 서버 설치
echo "🛠️ NFS 서버 설치 중..."
sudo apt update
sudo apt install -y nfs-kernel-server

### 5. /etc/exports 등록
echo "📦 NFS Export 설정 중..."
EXPORT_LINE="$SHARE_DIR *(rw,sync,no_subtree_check,no_root_squash)"
if ! grep -Fxq "$EXPORT_LINE" /etc/exports; then
  echo "$EXPORT_LINE" | sudo tee -a /etc/exports
fi
sudo exportfs -a
sudo systemctl restart nfs-kernel-server

### 6. Kubernetes PersistentVolume, PersistentVolumeClaim 생성
MASTER_IP=$(hostname -I | awk '{print $1}')

echo "📝 PV/PVC YAML 파일 생성 중..."
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


### 8. 완료 메시지
echo ""
echo "✅ 모든 설정이 완료되었습니다!"
echo "📂 공유폴더: $SHARE_DIR"
echo "📡 NFS 서버 IP: $MASTER_IP"
echo "🔗 PersistentVolume 이름: $PV_NAME"
echo "🔗 PersistentVolumeClaim 이름: $PVC_NAME (네임스페이스: $NAMESPACE)"
