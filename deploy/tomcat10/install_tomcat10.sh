#!/bin/bash
set -e

# 변수 설정
APP_NAME="blog-tomcat"
IMAGE_NAME="blog-tomcat:1.0"
LOCAL_REGISTRY="localhost:5000"
NAMESPACE="production"
BUILD_DIR="$HOME/k3s_rancher_autosetup/deploy/tomcat10"
UPLOAD_DIR="$HOME/blog_demo/uploads"

# [1] 업로드 경로 준비
echo "📁 업로드 폴더 생성: $UPLOAD_DIR"
mkdir -p "$UPLOAD_DIR"

# [2] Docker 이미지 빌드
echo "🐳 Docker 이미지 빌드 중..."
cd "$BUILD_DIR"
docker build -t $IMAGE_NAME .

# [3] 태그 및 레지스트리에 푸시
echo "📦 이미지 레지스트리 푸시 준비..."
docker tag $IMAGE_NAME $LOCAL_REGISTRY/$IMAGE_NAME
docker push $LOCAL_REGISTRY/$IMAGE_NAME

# [4] 네임스페이스 생성 (있으면 생략)
echo "🔧 네임스페이스 '$NAMESPACE' 생성 시도"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# [5] Deployment 및 Service 생성
echo "🚀 K3s에 Tomcat 배포 중..."

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
        volumeMounts:
        - name: uploads
          mountPath: /usr/local/tomcat/webapps/ROOT/blog_demo/uploads
      volumes:
      - name: uploads
        hostPath:
          path: $UPLOAD_DIR
          type: Directory
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

# [6] 결과 출력
echo ""
echo "✅ $APP_NAME 배포 완료!"
echo "🛰️ 접속 호스트: <워커노드 퍼블릭 IP>:30080"
echo "    또는 내부에서는: $APP_NAME.$NAMESPACE.svc.cluster.local:8080"
echo ""
kubectl get svc -n $NAMESPACE

# [7] Pod 준비 상태 대기 후 노드 정보 출력
echo "⏳ $APP_NAME Pod가 준비될 때까지 대기 중..."
kubectl wait --for=condition=Ready pod -l app=$APP_NAME -n $NAMESPACE --timeout=60s || echo "⚠️ Pod가 준비되지 않았습니다."

POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o jsonpath="{.items[0].metadata.name}")
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.spec.nodeName}")
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath="{.status.addresses[?(@.type==\"InternalIP\")].address}")
echo "📍 Tomcat Pod가 배치된 노드: $NODE_NAME ($NODE_IP)"
echo "🔗 Tomcat Pod 이름: $POD_NAME"
echo "🔗 Tomcat Pod IP: \$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath=\"{.status.podIP}\")"

