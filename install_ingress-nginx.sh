#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

### ⬆️ User input
read -p "Enter internal service address (e.g., http://blog-tomcat.production.svc.cluster.local:8080): " SERVICE_URL
if [[ -z "$SERVICE_URL" ]]; then
  echo "❌ Service address is required."
  exit 1
fi

read -p "Enter domain name (e.g., blog.example.com): " DOMAIN_NAME
if [[ -z "$DOMAIN_NAME" ]]; then
  echo "❌ Domain name is required."
  exit 1
fi

### Extract service name and port
SERVICE_HOST=$(echo "$SERVICE_URL" | awk -F[/:] '{print $4}')
SERVICE_PORT=$(echo "$SERVICE_URL" | sed -E 's|.*:([0-9]+)$|\1|')

### Extract only the service name (svc name)
SERVICE_NAME=$(echo "$SERVICE_HOST" | cut -d. -f1)

### Generate resource names based on domain
SANITIZED_DOMAIN="${DOMAIN_NAME//./-}"
SECRET_NAME="tls-${SANITIZED_DOMAIN}"
INGRESS_NAME="ingress-${SANITIZED_DOMAIN}"

### Check for duplicate domain
RECORD_FILE="./deploy/ingress_records.txt"
mkdir -p ./deploy
touch "$RECORD_FILE"

if grep -qE "DOMAIN=$DOMAIN_NAME\b" "$RECORD_FILE"; then
  echo "❌ Domain already registered: $DOMAIN_NAME"
  exit 1
fi

### Check certificate files in fixed location
CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
TLS_CRT="$CERT_DIR/server.crt.pem"
TLS_KEY="$CERT_DIR/server.key.pem"

if [[ ! -f "$TLS_CRT" || ! -f "$TLS_KEY" ]]; then
  echo "❌ Certificate files not found. ($TLS_CRT, $TLS_KEY)"
  exit 1
fi

### Check if Ingress Controller is installed
if ! kubectl get pods -A | grep -q 'ingress-nginx.*controller'; then
  echo "⚙️ Installing Ingress Controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml
  echo "⏳ Waiting for controller to be ready..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s
else
  echo "✅ Ingress Controller is already installed."
fi

### Create certificate secret
kubectl delete secret $SECRET_NAME --ignore-not-found -n production
kubectl create secret tls $SECRET_NAME \
  --cert="$TLS_CRT" \
  --key="$TLS_KEY" \
  -n production

### Create Ingress resource
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
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, PUT, POST, DELETE, PATCH, OPTIONS"
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

### Save record
echo "DOMAIN=$DOMAIN_NAME SECRET=$SECRET_NAME INGRESS=$INGRESS_NAME URL=$SERVICE_URL" >> "$RECORD_FILE"

### Get master node IP (for NodePort access)
MASTER_IP=$(kubectl get nodes -o wide | awk 'NR==2{print $6}')

echo ""
echo "✅ Ingress creation complete"
echo "➡️ External access: https://$DOMAIN_NAME (or https://$MASTER_IP with host header override)"
echo "➡️ Internal service: $SERVICE_NAME:$SERVICE_PORT (URL: $SERVICE_URL)"
