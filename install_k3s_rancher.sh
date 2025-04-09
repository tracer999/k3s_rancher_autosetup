#!/bin/bash

echo "[1/6] 시스템 업데이트 및 필수 패키지 설치"
sudo apt update && sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo "[2/6] k3s 설치"
curl -sfL https://get.k3s.io | sh -

echo "[3/6] Helm 설치"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

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

echo "설치 완료. http://<서버IP> 에서 Rancher 접속 가능 (기본 admin 계정)"