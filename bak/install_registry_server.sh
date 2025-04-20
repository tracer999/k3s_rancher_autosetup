#!/bin/bash
set -e

echo "📦 로컬 Docker 레지스트리 설치 스크립트 (포트: 5000)"

# [1] Docker 설치 여부 확인 및 설치
if ! command -v docker &> /dev/null; then
  echo "🐳 Docker가 설치되어 있지 않습니다. 설치를 진행합니다..."
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg lsb-release jq

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "✅ Docker 설치 완료"
fi

# [2] registry:2 실행 (이미 존재하면 스킵)
if ! docker ps --format '{{.Names}}' | grep -q '^registry$'; then
  sudo mkdir -p /opt/registry/data
  docker run -d --restart=always --name registry \
    -p 5000:5000 \
    -v /opt/registry/data:/var/lib/registry \
    registry:2
  echo "✅ registry:2 컨테이너가 포트 5000에서 실행되었습니다."
else
  echo "⚠️ registry 컨테이너가 이미 실행 중입니다."
fi

# [3] insecure-registries 설정
echo "🔧 /etc/docker/daemon.json 설정 중..."

REGISTRY_IP=$(hostname -I | awk '{print $1}')
DAEMON_JSON="/etc/docker/daemon.json"

# daemon.json 없으면 초기화
if [ ! -f "$DAEMON_JSON" ]; then
  echo '{}' | sudo tee "$DAEMON_JSON" > /dev/null
fi

# 기존 insecure-registries 유지 + 현재 IP 추가
sudo jq \
  --arg reg "$REGISTRY_IP:5000" \
  '. + { "insecure-registries": ( .["insecure-registries"] + [$reg] // [$reg] | unique ) }' \
  "$DAEMON_JSON" | sudo tee /tmp/daemon.json.tmp > /dev/null

sudo mv /tmp/daemon.json.tmp "$DAEMON_JSON"

# [4] Docker 재시작
echo "♻️ Docker 데몬 재시작 중..."
sudo systemctl daemon-reexec
sudo systemctl restart docker

# [5] registry_ip 파일로 저장
DEPLOY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo "$REGISTRY_IP" > "$DEPLOY_DIR/registry_ip"
echo "📝 registry_ip 파일 저장 완료: $DEPLOY_DIR/registry_ip"

# 완료 메시지
echo "🎉 레지스트리 설정 완료!"
echo "➡ Docker Push 예시:"
echo "   docker tag my-image $REGISTRY_IP:5000/my-image"
echo "   docker push $REGISTRY_IP:5000/my-image"
