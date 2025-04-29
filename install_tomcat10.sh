#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

### 🛠 기본 변수 설정
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$BASE_DIR/deploy/tomcat10"
REGISTRY_IP_FILE="$BASE_DIR/registry_ip"
DEPLOY_YAML="$DEPLOY_DIR/tomcat10.yaml"
NAMESPACE="production"

### [1] 사용자 입력 받기
echo "🌐 Tomcat 인스턴스 배포 스크립트 (k3s용)"

read -p "🌟 공통 접근용 서비스 이름 입력 (예: blog-tomcat): " GROUP_NAME
if [[ -z "$GROUP_NAME" ]]; then
  echo "❌ 서비스 이름은 필수입니다."
  exit 1
fi

read -p "🔁 배포할 Tomcat 인스턴스 수 (예: 2): " REPLICA_COUNT
REPLICA_COUNT=${REPLICA_COUNT:-2}

### [1-1] 추가 PVC 입력 받기
echo "📦 현재 $NAMESPACE 네임스페이스에 등록된 PVC 목록:"
kubectl get pvc -n $NAMESPACE
echo ""
read -p "📂 추가로 마운트할 PVC 이름 입력 (없으면 엔터): " PVC_NAME
PVC_NAME=${PVC_NAME:-}

### [2] 레지스트리 주소 확인
if [ ! -f "$REGISTRY_IP_FILE" ]; then
  echo "❌ registry_ip 파일이 없습니다: $REGISTRY_IP_FILE"
  exit 1
fi
REGISTRY_IP=$(cat "$REGISTRY_IP_FILE")
IMAGE_TAG="$GROUP_NAME:latest"
FULL_IMAGE_TAG="$REGISTRY_IP:5000/$IMAGE_TAG"

### [3] Docker 이미지 빌드 및 푸시 (공통 이미지)
echo "🔨 Tomcat 공통 이미지 빌드: $FULL_IMAGE_TAG"
docker build -t "$FULL_IMAGE_TAG" -f "$DEPLOY_DIR/Dockerfile" "$DEPLOY_DIR"
echo "📤 이미지 푸시 중..."
docker push "$FULL_IMAGE_TAG"

### [4] 기존 YAML 제거 후 새로 생성
if [ -f "$DEPLOY_YAML" ]; then
  echo "🗑 기존 배포 YAML 삭제: $DEPLOY_YAML"
  rm -f "$DEPLOY_YAML"
fi

echo "📝 새로운 배포 YAML 생성: $DEPLOY_YAML"

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

# PVC 입력이 있으면 volumeMount 추가
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

### [5] 기존 리소스 삭제
echo "🧹 기존 리소스 삭제 중..."
kubectl delete deployment "$GROUP_NAME" -n "$NAMESPACE" --ignore-not-found
kubectl delete service "$GROUP_NAME" -n "$NAMESPACE" --ignore-not-found

### [6] YAML로 일괄 배포
echo "🚀 YAML 파일을 이용한 배포 시작..."
kubectl apply -n "$NAMESPACE" -f "$DEPLOY_YAML"

### [7] 결과 출력
echo ""
echo "✅ [$GROUP_NAME] Tomcat $REPLICA_COUNT개 인스턴스(Pod)로 배포 완료!"
echo "📁 배포 YAML 저장 위치: $DEPLOY_YAML"
if [[ -n "$PVC_NAME" ]]; then
  echo "📂 추가 마운트된 PVC: $PVC_NAME → /blog_demo/uploads"
else
  echo "📂 PVC 추가 연결 없음"
fi
echo "🌐 내부 주소: http://$GROUP_NAME.$NAMESPACE.svc.cluster.local:8080"
echo "🌍 외부 접속 확인: kubectl get svc -n $NAMESPACE $GROUP_NAME"
