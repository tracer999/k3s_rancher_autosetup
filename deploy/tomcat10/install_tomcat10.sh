#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
IMAGE_TAG="tracer999/front_tomcat:latest"

echo "📦 DockerHub 기반 Tomcat10 + ROOT.war 배포 스크립트"

### 1. Docker 설치 확인
if ! command -v docker &> /dev/null; then
  echo "🐳 Docker가 설치되어 있지 않습니다. 설치를 진행합니다..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  echo "✅ Docker 설치 완료. 터미널 재접속이 필요할 수 있습니다."
else
  echo "✅ Docker가 이미 설치되어 있습니다."
fi
echo ""

### 2. Docker 이미지 빌드 및 푸시
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[1/3] Docker 이미지 빌드 중..."
docker build -t $IMAGE_TAG "$SCRIPT_DIR"

echo "[2/3] DockerHub로 푸시 중..."
docker push $IMAGE_TAG
echo "✅ DockerHub push 완료"
echo ""

### 3. Kubernetes 배포 (Deployment + Service)
echo "[3/3] Kubernetes 리소스 배포 중..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: front-tomcat
  labels:
    app: front-tomcat
spec:
  replicas: 1
  selector:
    matchLabels:
      app: front-tomcat
  template:
    metadata:
      labels:
        app: front-tomcat
    spec:
      hostname: front_tomcat
      containers:
      - name: front-tomcat
        image: $IMAGE_TAG
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: front-tomcat
spec:
  type: NodePort
  selector:
    app: front-tomcat
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 31080
EOF

echo ""
echo "✅ front-tomcat 서비스 배포 완료!"
echo "🌐 외부 접속 주소: http://<클러스터 내 워커노드 IP 중 하나>:31080"
echo "📛 내부 hostname: front_tomcat"
