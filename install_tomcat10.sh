#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

### 사용자로부터 서비스명 입력 받기
read -p "🌐 사용할 서비스 이름 (예: front-tomcat): " SERVICE_NAME
if [[ -z "$SERVICE_NAME" ]]; then
  echo "❌ 서비스 이름을 입력해야 합니다."
  exit 1
fi

### 기본 변수 정의
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy/tomcat10"
REGISTRY_IP_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/registry_ip"
IMAGE_TAG="$SERVICE_NAME:latest"
NAMESPACE="production"

### 1. registry_ip 파일 확인
if [ ! -f "$REGISTRY_IP_FILE" ]; then
  echo "⚠️ registry_ip 파일이 없습니다: $REGISTRY_IP_FILE"
  exit 1
fi
REGISTRY_IP=$(cat "$REGISTRY_IP_FILE")
FULL_IMAGE_TAG="$REGISTRY_IP:5000/$IMAGE_TAG"

### 2. Docker 설치 확인
if ! command -v docker &> /dev/null; then
  echo "🐳 Docker가 설치되지 않았습니다. 설치 진행합니다..."
  sudo apt update && sudo apt install -y docker.io
fi

### 3. Docker 이미지 빌드 + push
echo "[1/4] Docker 이미지 빌드: $FULL_IMAGE_TAG"
docker build -t $FULL_IMAGE_TAG "$DEPLOY_DIR"

echo "[2/4] 로컬 registry로 push..."
docker push $FULL_IMAGE_TAG

### 4. Kubernetes 배포 (Deployment + NodePort Service)
echo "[3/4] Kubernetes 배포"
kubectl delete deployment "$SERVICE_NAME" -n $NAMESPACE --ignore-not-found
kubectl delete service "$SERVICE_NAME" -n $NAMESPACE --ignore-not-found

cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $SERVICE_NAME
  labels:
    app: $SERVICE_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $SERVICE_NAME
  template:
    metadata:
      labels:
        app: $SERVICE_NAME
    spec:
      hostname: $SERVICE_NAME
      containers:
      - name: $SERVICE_NAME
        image: $FULL_IMAGE_TAG
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
spec:
  type: NodePort
  selector:
    app: $SERVICE_NAME
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 31080
EOF

### 5. 배포 상태 확인
echo "[4/4] Pod가 준비될 때까지 대기 중..."
if ! kubectl wait --for=condition=Ready pod -l app=$SERVICE_NAME -n $NAMESPACE --timeout=90s; then
  echo "⚠️ Pod가 준비되지 않았습니다. 상태 확인 명령어:"
  echo "   kubectl describe pod -l app=$SERVICE_NAME -n $NAMESPACE"
  echo "   kubectl logs $(kubectl get pod -l app=$SERVICE_NAME -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')"
  exit 1
fi

POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$SERVICE_NAME -o jsonpath="{.items[0].metadata.name}")
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.spec.nodeName}")
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath="{.status.addresses[?(@.type==\"InternalIP\")].address}")
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.status.podIP}")

echo "\n✅ Tomcat 배포 완료!"
echo "📍 배포된 노드: $NODE_NAME ($NODE_IP)"
echo "🔗 Pod 이름: $POD_NAME"
echo "🔗 Pod IP: $POD_IP"
echo "🔗 서비스 주소: http://$NODE_IP:31080"
