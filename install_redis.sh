#!/bin/bash
set -e

# 현재 스크립트 기준으로 deploy/redis 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/deploy/redis"

# ✅ kubeconfig 설정
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🛠️ Redis Helm Chart 자동 설치 스크립트"
echo "💡 production 네임스페이스가 없으면 생성됩니다."

# 사용자 입력 받기
read -p "Redis 서비스 이름 (Spring 등에서 사용할 호스트명): " REDIS_HOST

# 변수 설정
NAMESPACE="production"
RELEASE_NAME=$REDIS_HOST
CHART_NAME="bitnami/redis"
REPO_NAME="bitnami"
REPO_URL="https://charts.bitnami.com/bitnami"

# [1] 네임스페이스 생성
echo "[1/5] 네임스페이스 '$NAMESPACE' 생성 시도"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# [2] Helm Repo 등록
echo "[2/5] Helm 리포지토리 등록"
helm repo add $REPO_NAME $REPO_URL || true
helm repo update

# [3] values-redis.yaml 생성
echo "[3/5] values-redis.yaml 자동 생성"
cat <<EOF > values-redis.yaml
fullnameOverride: $REDIS_HOST

architecture: standalone

auth:
  enabled: true
  password: "NEWtec4075@"

master:
  service:
    type: NodePort
    nodePorts:
      redis: "31679"
  port: 6379

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 500m
EOF

# [4] Helm Chart 설치
echo "[4/5] Redis 설치 중..."
helm upgrade --install $RELEASE_NAME $CHART_NAME \
  --namespace $NAMESPACE \
  -f values-redis.yaml

# [5] 결과 출력
echo ""
echo "✅ Redis 설치 완료!"
echo "🛰️ 접속 호스트: <워커노드 퍼블릭 IP>:31679"
echo "    또는 내부에서는: $REDIS_HOST.$NAMESPACE.svc.cluster.local:6379"
echo ""
kubectl get svc -n $NAMESPACE

# Pod 상태 확인
echo "⏳ Redis Pod가 준비될 때까지 대기 중..."
if ! kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=$REDIS_HOST -n $NAMESPACE --timeout=90s; then
  echo "⚠️ Pod가 준비되지 않았습니다. 아래 명령어로 상태를 점검하세요:"
  echo "   kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/instance=$REDIS_HOST"
  echo "   kubectl logs -n $NAMESPACE pod/$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$REDIS_HOST -o jsonpath='{.items[0].metadata.name}')"
fi

# 노드 정보 출력
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$REDIS_HOST -o jsonpath="{.items[0].metadata.name}")
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.spec.nodeName}")
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath="{.status.addresses[?(@.type==\"InternalIP\")].address}")
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.status.podIP}")

echo "📍 Redis Pod가 배치된 노드: $NODE_NAME ($NODE_IP)"
echo "🔗 Redis Pod 이름: $POD_NAME"
echo "🔗 Redis Pod IP: $POD_IP"
echo "🔗 Redis 서비스 이름: $REDIS_HOST"

