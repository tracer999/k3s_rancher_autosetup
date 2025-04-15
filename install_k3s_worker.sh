#!/bin/bash

echo "▶️ k3s 워커 노드 설치 및 마스터 클러스터 연결 스크립트 (v2)"
echo ""

# ▶️ 필수 도구 확인 및 자동 설치
REQUIRED_TOOLS=("curl" "wget" "tar")

echo "🔍 필수 도구 확인 및 설치 중..."
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "📦 '$tool' 이(가) 설치되어 있지 않습니다. 설치합니다..."
    apt update && apt install -y "$tool"
    if [ $? -ne 0 ]; then
      echo "❌ '$tool' 설치에 실패했습니다. 수동으로 설치 후 다시 실행하세요."
      exit 1
    fi
  else
    echo "✅ '$tool' 설치됨"
  fi
done

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
systemctl status k3s-agent --no-pager || echo "⚠️ k3s-agent 서비스가 아직 생성되지 않았거나 실패했습니다."

echo ""
echo "✅ 워커 노드 설치 완료. 마스터에서 'kubectl get nodes'로 조인 상태를 확인하세요."
