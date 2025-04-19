#!/bin/bash
set -e

# 📍 현재 스크립트 기준 위치
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY_IP_FILE="$SCRIPT_DIR/../registry_ip"

# 🧠 마스터 IP 읽기
if [[ ! -f "$REGISTRY_IP_FILE" ]]; then
  echo "❌ registry_ip 파일이 없습니다: $REGISTRY_IP_FILE"
  echo "먼저 마스터에서 install_registry_server.sh 를 실행하세요."
  exit 1
fi

MASTER_IP=$(cat "$REGISTRY_IP_FILE")

APP_NAME="blog-tomcat"
IMAGE_NAME="blog-tomcat:1.0"
LOCAL_REGISTRY="$MASTER_IP:5000"
NAMESPACE="production"
BUILD_DIR="$SCRIPT_DIR"

# [1] Docker 이미지 빌드
echo "🐳 Docker 이미지 빌드 중..."
cd "$BUILD_DIR"
docker build -t $IMAGE_NAME .

# [2] 태그 및 레지스트리에 푸시
echo "📦 이미지 푸시 → $LOCAL_REGISTRY"
docker tag $IMAGE_NAME $LOCAL_REGISTRY/$IMAGE_NAME
docker push $LOCAL_REGISTRY/$IMAGE_NAME

# [3] 네임스페이스 준비
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# [4] 배포
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: $APP_NAME
        image: $LOCAL_REGISTRY/$IMAGE_NAME
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
spec:
  type: NodePort
  selector:
    app: $APP_NAME
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
EOF

# [5] 대기 및 출력
echo ""
echo "✅ $APP_NAME 배포 완료!"
kubectl wait --for=condition=Ready pod -l app=$APP_NAME -n $NAMESPACE --timeout=60s || echo "⚠️ Pod가 준비되지 않았습니다."

POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o jsonpath="{.items[0].metadata.name}")
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.spec.nodeName}")
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath="{.status.addresses[?(@.type==\"InternalIP\")].address}")
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.status.podIP}")

echo "🌐 내부 접근: $APP_NAME.$NAMESPACE.svc.cluster.local:8080"
echo "🛰️ 외부 접근: http://<워커노드 IP>:30080"
echo "📍 Pod 위치: $NODE_NAME ($NODE_IP)"
echo "🔗 Pod IP: $POD_IP"
