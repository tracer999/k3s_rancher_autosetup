#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

### ⬆️ 입력 받기
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

read -p "해당 서비스를 노출할 외부 포트 (예: 443): " EXTERNAL_PORT
if [[ -z "$EXTERNAL_PORT" ]]; then
  echo "❌ 포트 번호는 필수입니다."
  exit 1
fi

### 도메인 기반 이름 생성
SANITIZED_DOMAIN="${DOMAIN_NAME//./-}"
SECRET_NAME="tls-${SANITIZED_DOMAIN}"
INGRESS_NAME="ingress-${EXTERNAL_PORT}-${SANITIZED_DOMAIN}"

### 중복 도메인 확인
RECORD_FILE="./deploy/ingress_records.txt"
mkdir -p ./deploy
touch "$RECORD_FILE"

if grep -qE "DOMAIN=$DOMAIN_NAME\b" "$RECORD_FILE"; then
  echo "❌ 이미 등록된 도메인입니다: $DOMAIN_NAME"
  exit 1
fi

### 인증서 확인
CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
TLS_CRT="$CERT_DIR/server.all.crt.pem"
TLS_KEY="$CERT_DIR/server.key.pem"

if [[ ! -f "$TLS_CRT" || ! -f "$TLS_KEY" ]]; then
  echo "❌ 인증서 파일이 없습니다. ($TLS_CRT, $TLS_KEY)"
  exit 1
fi

### Ingress Controller 설치 확인
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

### Secret 등록 (도메인별 이름)
kubectl delete secret $SECRET_NAME --ignore-not-found -n production
kubectl create secret tls $SECRET_NAME \
  --cert="$TLS_CRT" \
  --key="$TLS_KEY" \
  -n production

### Ingress 생성
cat <<EOF | kubectl apply -n production -f -
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
    - $DOMAIN_NAME
    secretName: $SECRET_NAME
  rules:
  - host: $DOMAIN_NAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $(echo $SERVICE_URL | cut -d. -f1 | cut -d/ -f3)
            port:
              number: $(echo $SERVICE_URL | awk -F':' '{print $NF}')
EOF

### 기록 저장
echo "DOMAIN=$DOMAIN_NAME PORT=$EXTERNAL_PORT SECRET=$SECRET_NAME INGRESS=$INGRESS_NAME URL=$SERVICE_URL" >> "$RECORD_FILE"

echo ""
echo "✅ Ingress 설정 완료"
echo "➡️ 외부 접속: https://$DOMAIN_NAME:$EXTERNAL_PORT"
echo "➡️ 내부 라우팅 대상: $SERVICE_URL"
