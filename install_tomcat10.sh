#!/bin/bash
set -e

# ✅ kubeconfig 설정 (root로도 사용 가능하도록)
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🛠️ MySQL8 Helm Chart 자동 설치 스크립트"
echo "💡 production 네임스페이스가 없으면 생성됩니다."

# 사용자 입력 받기
read -p "생성할 DB 이름: " DB_NAME
read -p "DB 사용자 이름: " DB_USER
read -s -p "DB 비밀번호: " DB_PASSWORD
echo ""
read -p "MySQL 서비스 이름 (Spring에서 사용할 호스트명): " DB_HOST

# 변수 설정
NAMESPACE="production"
RELEASE_NAME=$DB_HOST
CHART_NAME="bitnami/mysql"
REPO_NAME="bitnami"
REPO_URL="https://charts.bitnami.com/bitnami"
INIT_SQL_PATH="./init-sql/database_dump.sql"

# [1] 네임스페이스 생성
echo "[1/6] 네임스페이스 '$NAMESPACE' 생성 시도"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# [2] ConfigMap 삭제 후 재생성
echo "[2/6] 초기 SQL(database_dump.sql)로 ConfigMap 재생성"
kubectl delete configmap mysql-initdb -n $NAMESPACE --ignore-not-found
if [ ! -f "$INIT_SQL_PATH" ]; then
  echo "❌ 파일이 존재하지 않습니다: $INIT_SQL_PATH"
  exit 1
fi
kubectl create configmap mysql-initdb \
  --from-file=init.sql=$INIT_SQL_PATH \
  -n $NAMESPACE

# [3] Helm Repo 등록
echo "[3/6] Helm 리포지토리 등록"
helm repo add $REPO_NAME $REPO_URL || true
helm repo update

# [4] values-mysql.yaml 생성
echo "[4/6] values-mysql.yaml 자동 생성"
cat <<EOF > values-mysql.yaml
fullnameOverride: $DB_HOST

auth:
  rootPassword: rootpassword
  username: $DB_USER
  password: $DB_PASSWORD
  database: $DB_NAME
  authenticationPlugin: mysql_native_password

primary:
  service:
    type: NodePort
    nodePorts:
      mysql: 31060
  port: 3306

  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 768Mi
      cpu: 750m

initdbScriptsConfigMap: mysql-initdb
EOF

# [5] Helm Chart 설치
echo "[5/6] MySQL8 설치 중..."
helm upgrade --install $RELEASE_NAME $CHART_NAME \
  --namespace $NAMESPACE \
  -f values-mysql.yaml

# [6] 결과 출력
echo ""
echo "✅ MySQL8 설치 완료!"
echo "📛 DB 이름: $DB_NAME"
echo "👤 사용자: $DB_USER"
echo "🔐 비밀번호: $DB_PASSWORD"
echo "🛰️ 접속 호스트: <워커노드 퍼블릭 IP>:31060"
echo "    또는 내부에서는: $DB_HOST.$NAMESPACE.svc.cluster.local:3306"
echo ""
kubectl get svc -n $NAMESPACE

# [7] Pod 상태 확인
echo "⏳ MySQL Pod가 준비될 때까지 대기 중..."
if ! kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=$DB_HOST -n $NAMESPACE --timeout=90s; then
  echo "⚠️ Pod가 준비되지 않았습니다. 아래 명령어로 상태를 점검하세요:"
  echo "   kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/instance=$DB_HOST"
  echo "   kubectl logs -n $NAMESPACE pod/$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$DB_HOST -o jsonpath='{.items[0].metadata.name}')"
fi

# [8] 노드 정보 출력
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$DB_HOST -o jsonpath="{.items[0].metadata.name}")
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.spec.nodeName}")
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath="{.status.addresses[?(@.type==\"InternalIP\")].address}")
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.status.podIP}")

echo "📍 MySQL Pod가 배치된 노드: $NODE_NAME ($NODE_IP)"
echo "🔗 MySQL Pod 이름: $POD_NAME"
echo "🔗 MySQL Pod IP: $POD_IP"
echo "🔗 MySQL 서비스 이름: $DB_HOST"