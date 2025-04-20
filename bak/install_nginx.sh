#!/bin/bash
set -e

# 📁 디렉토리 이동 (deploy/nginx 기준)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/deploy/nginx"

# ✅ kubeconfig 설정
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# === 사용자 입력 ===
echo "🌐 프록시 대상 백엔드 경로를 입력하세요 (예: http://front-tomcat:8080):"
read -p "👉 대상 URL: " BACKEND_URL
if [[ -z "$BACKEND_URL" ]]; then
  echo "❌ 대상 URL을 입력해야 합니다."
  exit 1
fi

read -p "🌍 사용하려는 도메인명을 입력하세요 (예: www.example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "❌ 도메인명을 입력해야 Ingress 리소스를 생성할 수 있습니다."
  exit 1
fi

# === 변수 정의 ===
NAMESPACE="production"
CERT_DIR="$SCRIPT_DIR/certs"
TLS_SECRET_NAME="nginx-tls-secret"
INGRESS_NAME="nginx-proxy"
INGRESS_FILE="ingress-nginx.yaml"

# 인증서 파일 확인
CRT_FILE="$CERT_DIR/server.all.crt.pem"
KEY_FILE="$CERT_DIR/server.key.pem"
if [[ ! -f "$CRT_FILE" || ! -f "$KEY_FILE" ]]; then
  echo "❌ 인증서 또는 키 파일이 없습니다: ($CRT_FILE, $KEY_FILE)"
  exit 1
fi

# [1/6] 네임스페이스 생성
echo "[1/6] 네임스페이스 '$NAMESPACE' 생성 시도"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# [2/6] TLS Secret 생성
echo "[2/6] TLS Secret 생성 중: $TLS_SECRET_NAME"
kubectl delete secret $TLS_SECRET_NAME -n $NAMESPACE --ignore-not-found
kubectl create secret tls $TLS_SECRET_NAME \
  --cert="$CRT_FILE" \
  --key="$KEY_FILE" \
  -n $NAMESPACE

# [3/6] Ingress Nginx Controller 설치 (hostPort 방식, 모든 노드에 배포)
echo "[3/6] Ingress Nginx Controller 설치"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace $NAMESPACE \
  --create-namespace \
  --set controller.kind=DaemonSet \
  --set controller.hostNetwork=true \
  --set controller.daemonset.useHostPort=true \
  --set controller.containerPort.http=80 \
  --set controller.containerPort.https=443 \
  --set controller.service.type="" \
  --set controller.ingressClassResource.default=true

# [4/6] Ingress Controller Pod 준비 대기
echo "⏳ Ingress Nginx Controller Pod가 준비될 때까지 대기 중..."
if ! kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=ingress-nginx -n $NAMESPACE --timeout=120s; then
  echo "⚠️ Ingress Controller Pod가 준비되지 않았습니다. 아래 명령어로 상태를 점검하세요:"
  echo "   kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/name=ingress-nginx"
  echo "   kubectl logs -n $NAMESPACE pod/$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')"
  exit 1
fi

# [5/6] Ingress YAML 생성 (항상 재생성)
echo "📄 Ingress YAML을 새로 생성합니다: $INGRESS_FILE"
cat <<EOF > $INGRESS_FILE
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $INGRESS_NAME
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  tls:
  - hosts:
    - "$DOMAIN"
    secretName: $TLS_SECRET_NAME
  rules:
  - host: "$DOMAIN"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: front-tomcat
            port:
              number: 8080
EOF

# [6/6] Ingress 리소스 적용
echo "[6/6] Ingress 리소스 적용 중..."
kubectl delete ingress $INGRESS_NAME -n $NAMESPACE --ignore-not-found
kubectl apply -f $INGRESS_FILE -n $NAMESPACE

# ✅ 완료 메시지
echo ""
echo "✅ Nginx Ingress 배포 완료!"
echo "📡 외부에서 접속: https://$DOMAIN (443 포트)"
echo "📄 적용된 Ingress YAML: deploy/nginx/$INGRESS_FILE"

# 배포 위치 출력
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=ingress-nginx -o jsonpath="{.items[0].metadata.name}")
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.spec.nodeName}")
NODE_IP=$(kubectl get node $NODE_NAME -o jsonpath="{.status.addresses[?(@.type==\"InternalIP\")].address}")
POD_IP=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath="{.status.podIP}")

echo "📍 Ingress Pod가 배치된 노드: $NODE_NAME ($NODE_IP)"
echo "🔗 Ingress Pod 이름: $POD_NAME"
echo "🔗 Ingress Pod IP: $POD_IP"
