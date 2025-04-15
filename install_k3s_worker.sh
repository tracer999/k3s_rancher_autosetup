#!/bin/bash

echo "▶️ k3s 워커 노드 설치 및 마스터 클러스터 연결 스크립트 (토큰 직접 입력 방식)"
echo ""

read -p "마스터 서버의 IP를 입력하세요: " MASTER_IP
read -p "마스터에서 복사한 노드 토큰을 붙여넣으세요: " TOKEN

if [ -z "$TOKEN" ]; then
  echo "❌ 토큰이 비어 있습니다. 마스터에서 토큰을 복사한 후 다시 실행해주세요."
  exit 1
fi

# curl 설치 여부 확인
if ! command -v curl >/dev/null 2>&1; then
  echo "❌ 'curl' 명령어가 없습니다. 아래 명령어로 먼저 설치해주세요:"
  echo "    sudo apt update && sudo apt install -y curl"
  exit 1
fi

echo ""
echo "[1/2] k3s 에이전트 설치 중..."
curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN sh -

echo ""
echo "[2/2] 서비스 상태 확인:"
systemctl status k3s-agent --no-pager || echo "⚠️ k3s-agent 서비스가 아직 생성되지 않았거나 실패했습니다."

echo ""
echo "✅ 워커 노드 설치 완료. 마스터에서 'kubectl get nodes'로 노드가 조인되었는지 확인하세요."
echo "⚠️ k3s-agent 서비스가 실패한 경우, 'sudo journalctl -u k3s-agent -f'로 로그를 확인하세요."
echo "⚠️ 마스터 노드에서 'kubectl get nodes' 명령어로 노드 상태를 확인하세요."