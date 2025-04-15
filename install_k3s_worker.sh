#!/bin/bash

echo "▶️ k3s 워커 노드 설치 및 마스터 클러스터 연결 스크립트 (토큰 직접 입력 방식)"
echo ""

read -p "마스터 서버의 IP를 입력하세요: " MASTER_IP
read -p "마스터에서 복사한 노드 토큰을 붙여넣으세요: " TOKEN

if [ -z "$TOKEN" ]; then
  echo "❌ 토큰이 비어 있습니다. 마스터에서 토큰을 복사한 후 다시 실행해주세요."
  exit 1
fi

echo ""
echo "[1/2] k3s 에이전트 설치 중..."
curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN sh -

echo ""
echo "[2/2] 서비스 상태 확인:"
systemctl status k3s-agent --no-pager

echo ""
echo "✅ 워커 노드가 마스터에 정상적으로 조인되었습니다."
echo "🔁 마스터에서 'kubectl get nodes'로 등록 여부를 확인하세요."
echo "⚠️ 설치 후 마스터에서 'kubectl get nodes' 명령어로 노드 상태를 확인하세요."