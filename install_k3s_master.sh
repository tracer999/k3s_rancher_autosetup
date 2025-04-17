#!/bin/bash

echo "[1/6] 시스템 업데이트 및 필수 패키지 설치"
sudo apt update && sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo "[2/6] k3s 서버 설치"
curl -sfL https://get.k3s.io | sh -

echo "[3/6] Helm 설치"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[4/6] kubectl 설정"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc

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

echo "[7/7] Rancher 서비스 타입을 NodePort로 변경"
kubectl patch svc rancher -n cattle-system -p '{"spec": {"type": "NodePort"}}'

echo ""
echo "✅ 설치 완료. Rancher에 접속하려면 아래 포트를 확인하세요:"
kubectl get svc rancher -n cattle-system

echo ""
echo "✅ 설치 완료. 다음 정보를 워커 노드에 복사해 입력해야 합니다:"
echo "서버 주소: $(hostname -I | awk '{print $1}')"
echo "Join Token:"
sudo cat /var/lib/rancher/k3s/server/node-token
echo ""
echo "➡ http://<서버IP> 에서 Rancher 접속 가능 (기본 admin 계정)"

