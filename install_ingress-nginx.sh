#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

### ⬆️ 사용자 입력
read -p "내부 Service 주소 입력 (예: http://blog-tomcat.production.svc.cluster.local:8080): " SERVICE_URL
if [[ -z "$SERVICE_URL" ]]; then
  echo "❌ 서비스 주소는 필수입니다."
  exit 1
fi

read -p "도메인 입력 (예: blog.example.com): " DOMAIN_NAME
if [[ -z "$DOMAIN_NAME" ]]; then
  echo "❌ 도메인은 필수입니다."
  exit 1
fi

### 서비스 이름 및 포트 추출
SERVICE_HOST=$(echo "$SERVICE_URL" | awk -F[/:] '{print $4}')
SERVICE_PORT=$(echo "$SERVICE_URL" | sed -E 's|.*:([0-9]+)$|\1|')

### 내부 서비스 이름만 추출 (svc name)
SERVICE_NAME=$(echo "$SERVICE_HOST" | cut -d. -f1)

### 도메인 기반 리소스 이름 생성
SANITIZED_DOMAIN="${DOMAIN_NAME//./-}"
SECRET_NAME="tls-${SANITIZED_DOMAIN}"
INGRESS_NAME="ingress-${SANITIZED_DOMAIN}"

### 중복 도메인 체크
RECORD_FILE="./deploy/ingress_records.txt"
mkdir -p ./deploy
touch "$RECORD_FILE"

if grep -qE "DOMAIN=$DOMAIN_NAME\b" "$RECORD_FILE"; then
  echo "❌ 이미 등록된 도메인입니다: $DOMAIN_NAME"
  exit 1
fi

### 고정된 인증서 위치 확인
CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
TLS_CRT="$CERT_DIR/server.crt.pem"
TLS_KEY="$CERT_DIR/server.key.pem"

if [[ ! -f "$TLS_CRT" || ! -f "$TLS_KEY" ]]; then
  echo "❌ 인증서 파일이 없습니다. ($TLS_CRT, $TLS_KEY)"
  exit 1
fi

### Ingress Controller 설치 여부 확인
if ! kubectl get pods -A | grep -q 'ingress-nginx.*controller'; then
  echo "⚙️ Ingress Controller 설치 중..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml
  echo "⏳ 준비 대기 중..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s
else
  echo "✅ Ingress Controller가 이미 설치되어 있습니다."
fi

### 인증서 Secret 생성
kubectl delete secret $SECRET_NAME --ignore-not-found -n production
kubectl create secret tls $SECRET_NAME \
  --cert="$TLS_CRT" \
  --key="$TLS_KEY" \
  -n production

### Ingress 리소스 생성
cat <<EOF | kubectl apply -n production -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $INGRESS_NAME
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"   
    nginx.ingress.kubernetes.io/enable-modsecurity: "false"  
    nginx.ingress.kubernetes.io/enable-owasp-core-rules: "false"  
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
            name: $SERVICE_NAME
            port:
              number: $SERVICE_PORT
EOF

### 기록 저장
echo "DOMAIN=$DOMAIN_NAME SECRET=$SECRET_NAME INGRESS=$INGRESS_NAME URL=$SERVICE_URL" >> "$RECORD_FILE"

### 마스터 노드 IP 확인 (NodePort용)
MASTER_IP=$(kubectl get nodes -o wide | awk 'NR==2{print $6}')

echo ""
echo "✅ Ingress 생성 완료"
echo "➡️ 외부 접속: https://$DOMAIN_NAME (또는 https://$MASTER_IP 에서 host 헤더 적용)"
echo "➡️ 내부 서비스: $SERVICE_NAME:$SERVICE_PORT (URL: $SERVICE_URL)"
