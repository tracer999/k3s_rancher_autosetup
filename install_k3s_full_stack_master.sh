#!/bin/bash

echo "▶️ Rancher 설치용 k3s 마스터 자동 구성 스크립트 (Let's Encrypt 포함)"
echo "⚠️ 반드시 root 계정으로 실행하세요."
echo ""

# 사용자 입력 받기
read -p "도메인을 입력하세요 (예: yanghajin.com): " DOMAIN
read -p "인증서 발급용 이메일을 입력하세요: " EMAIL
read -s -p "초기 admin 비밀번호를 입력하세요: " ADMIN_PASSWORD
echo ""

echo "[0/7] 필수 패키지 설치 중..."
apt update
apt install -y curl wget ca-certificates gnupg lsb-release tar

echo "[1/7] k3s 설치 중..."
curl -sfL https://get.k3s.io | sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# kubectl 심볼릭 링크 설정
if [ ! -f "/usr/local/bin/kubectl" ]; then
  ln -s /usr/local/bin/k3s /usr/local/bin/kubectl
fi

# PATH 보정
export PATH=$PATH:/usr/local/bin

echo "[2/7] Helm 설치 중..."
HELM_VERSION="v3.13.3"
curl -LO https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz
tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm && chmod +x /usr/local/bin/helm
rm -rf helm-${HELM_VERSION}-linux-amd64.tar.gz linux-amd64

echo "[3/7] cert-manager 설치 중..."
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true

echo "[4/7] ClusterIssuer 생성 중..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo "[5/7] Rancher 네임스페이스 생성"
kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -

echo "[6/7] Rancher 설치 중..."
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=${DOMAIN} \
  --set replicas=1 \
  --set bootstrapPassword=${ADMIN_PASSWORD} \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=${EMAIL} \
  --set letsEncrypt.ingress.class=nginx \
  --set letsEncrypt.environment=production

echo "[7/7] 마스터 토큰 저장 (/tmp/k3s_token.txt)"
cat /var/lib/rancher/k3s/server/node-token > /tmp/k3s_token.txt

echo ""
echo "✅ Rancher 설치 완료!"
echo "🔗 접속 주소: https://${DOMAIN}"
echo "🆔 관리자 ID: admin"
echo "🔑 비밀번호: ${ADMIN_PASSWORD}"
echo ""
echo "📄 워커 노드 추가 시 /tmp/k3s_token.txt를 참조하세요."

