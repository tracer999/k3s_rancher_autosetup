#!/bin/bash
set -e

echo "🧩 k3s 클러스터 구성 스크립트"
echo "1) 마스터 노드 설치"
echo "2) 워커 노드 설치"
read -p "선택하세요 (1 or 2): " mode

if [[ "$mode" == "1" ]]; then
  echo "🛠 마스터 노드 설치 시작..."

  echo "[1/7] 시스템 업데이트 및 필수 패키지 설치"
  sudo apt update && sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

  echo "[2/7] k3s 서버 설치"
  curl -sfL https://get.k3s.io | sh -

  echo "[3/7] Helm 설치"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


  echo "[4/7] kubeconfig 설정 (모든 사용자 접근 허용)"
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' | sudo tee -a /etc/profile /etc/bash.bashrc > /dev/null
  sudo chmod +r /etc/rancher/k3s/k3s.yaml
  echo '✅ 모든 사용자에 대해 KUBECONFIG 환경변수 및 권한 설정 완료'





  echo "[5/7] cert-manager 설치"
  kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm install cert-manager jetstack/cert-manager --namespace cattle-system --set installCRDs=true

  echo "[6/7] Rancher 설치"
  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
  helm repo update
  helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --set hostname=rancher.localhost \
    --set replicas=1 \
    --set bootstrapPassword=admin

  echo "[7/7] Rancher 서비스 타입을 NodePort로 변경"
  kubectl patch svc rancher -n cattle-system -p '{"spec": {"type": "NodePort"}}'

  echo "🌱 production 네임스페이스 생성"
  kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

  echo ""
  echo "✅ 마스터 노드 설치 및 Rancher 배포 완료"
  echo "➡ Rancher 접속: http://<마스터 서버 IP>:<노드포트>"
  echo "서버 주소: $(hostname -I | awk '{print $1}')"
  echo "Join Token:"
  sudo cat /var/lib/rancher/k3s/server/node-token

elif [[ "$mode" == "2" ]]; then
  echo "🔗 워커 노드 설치 시작..."

  read -p "마스터 노드의 IP 입력: " master_ip
  read -p "Join 토큰 입력: " token

  echo "[1/2] k3s 에이전트 설치"
  curl -sfL https://get.k3s.io | K3S_URL=https://$master_ip:6443 K3S_TOKEN=$token sh -

  echo ""
  echo "✅ 워커 노드 설치 완료"
  echo "💡 Rancher에서 클러스터 상태 확인 가능"

else
  echo "❌ 잘못된 선택입니다. 1 또는 2를 입력하세요."
  exit 1
fi

