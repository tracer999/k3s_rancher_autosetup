#!/bin/bash

echo "▶️ k3s 워커 노드 설치 및 마스터 클러스터 연결 스크립트"

read -p "마스터 서버의 IP를 입력하세요: " MASTER_IP
read -p "마스터 서버의 노드 토큰 경로 (예: /tmp/k3s_token.txt): " TOKEN_FILE

if [ ! -f "$TOKEN_FILE" ]; then
  echo "❌ 토큰 파일이 존재하지 않습니다: $TOKEN_FILE"
  exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")

echo "[1/3] k3s 에이전트 설치 중..."
curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN sh -

echo "[2/3] 서비스 상태 확인 중..."
sudo systemctl status k3s-agent --no-pager

echo "[3/3] 노드가 마스터에 조인되었는지 확인하세요 (마스터에서 'kubectl get nodes')"

echo "✅ 워커 설치 및 조인 완료"
