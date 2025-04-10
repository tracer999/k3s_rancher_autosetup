#!/bin/bash

set -e

echo "[1/6] 시스템 업데이트 및 필수 패키지 설치"
dnf update -y && dnf install -y curl wget ca-certificates gnupg2 lsb_release tar gzip

echo "[2/6] k3s 설치"
curl -sfL https://get.k3s.io | sh -

# kubectl 심볼릭 링크 확인 및 설정
if [ ! -f "/usr/local/bin/kubectl" ]; then
    ln -s /usr/local/bin/k3s /usr/local/bin/kubectl
    echo "[INFO] kubectl 심볼릭 링크 생성됨"
else
    echo "[INFO] /usr/local/bin/kubectl 이 이미 있습니다. 건너뜁니다."
fi

# PATH에 /usr/local/bin 추가 (현재 세션과 프로필에 반영)
export PATH=$PATH:/usr/local/bin
if ! grep -q '/usr/local/bin' ~/.bash_profile; then
    echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bash_profile
fi
source ~/.bash_profile

echo "[3/6] Helm 설치"
HELM_VERSION="v3.13.3"
curl -LO https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz
tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm && chmod +x /usr/local/bin/helm
rm -rf helm-${HELM_VERSION}-linux-amd64.tar.gz linux-amd64

if ! command -v helm &> /dev/null; then
    echo "[ERROR] Helm 설치에 실패했습니다."
    exit 1
else
    echo "[INFO] Helm 설치 완료"
fi

echo "[4/6] kubectl 설정"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "[5/6] cert-manager 설치"
kubectl create namespace cattle-system
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cattle-system --set installCRDs=true

echo "[6/6] Rancher 설치"
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.localhost \
  --set replicas=1 \
  --set bootstrapPassword=admin

echo "✅ 설치 완료. http://<서버IP> 에서 Rancher 접속 가능 (기본 admin 계정)"
