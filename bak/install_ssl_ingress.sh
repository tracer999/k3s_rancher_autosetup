#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🔐 Ingress + TLS HTTPS 구성 스크립트"

### 1️⃣ 사용자 입력
read -p "연결할 내부 Service 주소 입력 (예: http://blog-tomcat.production.svc.cluster.local:8080): " SERVICE_URL
if [[ -z "$SERVICE_URL" ]]; then
  echo "❌ 서비스 주소는 필수입니다."
  exit 1
fi

read -p "사용할 도메인 입력 (예: blog.example.com): " DOMAIN_NAME
if [[ -z "$DOMAIN_NAME" ]]; then
  echo "❌ 도메인은 필수입니다."
  exit 1
fi

read -p "HTTPS 외부 포트 입력 (예: 443): " EXTERNAL_PORT
if [[ -z "$EXTERNAL_PORT" ]]; then
  echo "❌ 포트 번호는 필수입니다."
  exit 1
fi

### 2️⃣ 중복 확인 및 기록 파일 설정
RECORD_FILE="./deploy/ingress_records.txt"
mkdir -p ./deploy
touch "$RECORD_FILE"

if grep -qE "DOMAIN=$DOMAIN_NAME\b" "$RECORD_FILE"; then
  echo "❌ 이미 등록된 도메인입니다: $DOMAIN_NAME"
  exit 1
fi

### 3️⃣ 인증서 존재 확인
CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
TLS_CRT="$CERT_DIR/server.all.crt.pem"
TLS_KEY="$CERT_DIR/server.key.pem"

if [[ ! -f "$TLS_CRT" || ! -f "$TLS_KEY" ]]; then
  echo "❌ 인증서 파일이 없습니다: $TLS_CRT 또는 $TLS_KEY"
  exit 1
fi

### 4️⃣ Ingress Controller 설치 여부 확인
if ! kubectl get pods -A | grep -q 'ingress-nginx.*controller'; then
  echo "⚙️ Ingress Controller가 없으므로 설치합니다..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml
  echo "⏳ Ingress Controller 준비 대기 중..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s
else
  echo "✅ Ingress Controller가 이미 설치되어 있습니다."
fi

### 5️⃣ TLS Secret 생성
kubectl delete secret tls-$EXTERNAL_PORT --ignore-not-found -n production
kubectl create secret tls tls-$EXTERNAL_PORT \
  --cert="$TLS_CRT" \
  --key="$TLS_KEY" \
  -n production

### 6️⃣ Ingress 리소스 생성
cat <<EOF | kubectl apply -n production -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-$EXTERNAL_PORT-$DOMAIN_NAME
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $DOMAIN_NAME
    secretName: tls-$EXTERNAL_PORT
  rules:
  - host: $DOMAIN_NAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $(echo "$SERVICE_URL" | cut -d. -f1 | cut -d/ -f3)
            port:
              number: $(echo "$SERVICE_URL" | awk -F':' '{print $NF}')
EOF

### 7️⃣ 기록 저장
echo "DOMAIN=$DOMAIN_NAME PORT=$EXTERNAL_PORT URL=$SERVICE_URL" >> "$RECORD_FILE"

### ✅ 완료 메시지
echo ""
echo "✅ Ingress + TLS HTTPS 설정 완료!"
echo "➡️ 외부 접속: https://$DOMAIN_NAME:$EXTERNAL_PORT"
echo "➡️ 내부 라우팅 대상: $SERVICE_URL"
echo "📌 보안 그룹에서 포트 $EXTERNAL_PORT 를 반드시 열어주세요."
