#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

### 🛠 기본 변수 설정
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$BASE_DIR/deploy/tomcat10"
REGISTRY_IP_FILE="$BASE_DIR/registry_ip"
NAMESPACE="production"

### [1] 사용자 입력 받기
read -p "🌐 공통 접근용 서비스 이름 입력 (예: blog-tomcat): " GROUP_NAME
if [[ -z "$GROUP_NAME" ]]; then
  echo "❌ 서비스 이름은 필수입니다."
  exit 1
fi

read -p "🔁 배포할 Tomcat 인스턴스 수 (예: 2): " INSTANCE_COUNT
INSTANCE_COUNT=${INSTANCE_COUNT:-2}

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
docker build -t "$FULL_IMAGE_TAG" "$DEPLOY_DIR"
echo "📤 이미지 푸시 중..."
docker push "$FULL_IMAGE_TAG"

### [4] 인스턴스별 배포 반복
for i in $(seq 1 "$INSTANCE_COUNT"); do
  INSTANCE_NAME="${GROUP_NAME}-${i}"

  echo ""
  echo "🚀 [$INSTANCE_NAME] 배포 시작..."

  # 기존 리소스 삭제 (있을 경우)
  kubectl delete deployment "$INSTANCE_NAME" -n $NAMESPACE --ignore-not-found
  kubectl delete service "$INSTANCE_NAME" -n $NAMESPACE --ignore-not-found

  # Deployment + NodePort Service 생성
  cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $INSTANCE_NAME
  labels:
    app: $GROUP_NAME
    instance: $INSTANCE_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      instance: $INSTANCE_NAME
  template:
    metadata:
      labels:
        app: $GROUP_NAME
        instance: $INSTANCE_NAME
    spec:
      containers:
      - name: $INSTANCE_NAME
        image: $FULL_IMAGE_TAG
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: $INSTANCE_NAME
  labels:
    app: $GROUP_NAME
spec:
  type: NodePort
  selector:
    instance: $INSTANCE_NAME
  ports:
  - name: http
    port: 8080
    targetPort: 8080
EOF

done

### [5] 공통 접근용 ClusterIP 생성
echo ""
echo "🔗 ClusterIP 서비스 ($GROUP_NAME) 생성 중..."
kubectl delete service $GROUP_NAME -n $NAMESPACE --ignore-not-found

cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Service
metadata:
  name: $GROUP_NAME
spec:
  type: ClusterIP
  selector:
    app: $GROUP_NAME
  ports:
  - port: 8080
    targetPort: 8080
EOF

### [6] 결과 출력
echo ""
echo "✅ [$GROUP_NAME] Tomcat 인스턴스 $INSTANCE_COUNT개 배포 완료!"
echo "🌐 내부 접근 주소 (ClusterIP): http://$GROUP_NAME.$NAMESPACE.svc.cluster.local:8080"
echo "🌍 외부 접근 (NodePort): 아래 명령어로 확인하세요:"
echo "   kubectl get svc -n $NAMESPACE -l app=$GROUP_NAME"
