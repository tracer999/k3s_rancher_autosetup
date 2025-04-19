#!/bin/bash
set -e

echo "🧹 로컬 Docker 레지스트리 삭제 스크립트"

# 1. Registry 컨테이너 중지 및 삭제
if sudo docker ps -a --format '{{.Names}}' | grep -q '^registry$'; then
  echo "🛑 registry 컨테이너 중지 및 삭제"
  sudo docker stop registry
  sudo docker rm registry
else
  echo "ℹ️ registry 컨테이너가 존재하지 않습니다"
fi

# 2. 데이터 디렉토리 삭제
echo "🗑️ /opt/registry/data 삭제"
sudo rm -rf /opt/registry/data

# 3. insecure-registry 설정 제거
if [ -f /etc/docker/daemon.json ]; then
  echo "🧼 daemon.json에서 insecure-registry 설정 제거"
  sudo jq 'del(.["insecure-registries"])' /etc/docker/daemon.json > /tmp/daemon.json.tmp
  sudo mv /tmp/daemon.json.tmp /etc/docker/daemon.json
fi

# 4. Docker 재시작
echo "♻️ Docker 재시작 중..."
sudo systemctl restart docker

echo "✅ 레지스트리 및 관련 설정 제거 완료"

