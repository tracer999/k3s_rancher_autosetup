#!/bin/bash

set -e
echo "[1/4] k3s 서버 설치"
curl -sfL https://get.k3s.io | sh -

echo "[2/4] kubectl 설정"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "[3/4] k3s 노드 토큰 확인"
cat /var/lib/rancher/k3s/server/node-token > /tmp/k3s_token.txt
echo "🔑 노드 토큰:"
cat /tmp/k3s_token.txt

echo "[4/4] Rancher 설치"
# Helm 설치
curl -LO https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz
tar -zxvf helm-v3.13.3-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm

# cert-manager 설치
kubectl create namespace cattle-system
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cattle-system --set installCRDs=true

# Rancher 설치
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.localhost \
  --set bootstrapPassword=admin

echo "✅ Rancher 설치 완료. http://<마스터IP> 로 접속 가능 (ID: admin / PW: admin)"

