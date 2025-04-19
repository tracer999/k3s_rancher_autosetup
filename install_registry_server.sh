#!/bin/bash
set -e

# ✅ Docker 설치 여부 확인 및 설치
if ! command -v docker &> /dev/null; then
  echo "🐳 Docker가 설치되어 있지 않습니다. 설치를 진행합니다..."
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg lsb-release
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "✅ Docker 설치 완료"
fi

echo "📦 로컬 Docker 레지스트리 설치 스크립트 (포트: 5000)"

# 1. 데이터 디렉토리 생성
sudo mkdir -p /opt/registry/data

# 2. Docker Registry 컨테이너 실행
sudo docker run -d --restart=always --name registry \
  -p 5000:5000 \
  -v /opt/registry/data:/var/lib/registry \
  registry:2

echo "✅ registry:2 컨테이너가 포트 5000에서 실행되었습니다."

# 3. insecure-registry 설정 추가
echo "🔧 /etc/docker/daemon.json 설정 업데이트 중..."

if [ ! -f /etc/docker/daemon.json ]; then
  echo '{}' | sudo tee /etc/docker/daemon.json
fi

sudo jq '. + {"insecure-registries": ["localhost:5000", "127.0.0.1:5000"]}' /etc/docker/daemon.json > /tmp/daemon.json.tmp
sudo mv /tmp/daemon.json.tmp /etc/docker/daemon.json

# 4. Docker 재시작
echo "♻️ Docker 재시작 중..."
sudo systemctl daemon-reexec
sudo systemctl restart docker

echo "🎉 로컬 Docker 레지스트리 설치 완료!"
echo "➡ 테스트 예시:"
echo "   docker tag blog-tomcat:1.0 localhost:5000/blog-tomcat:1.0"
echo "   docker push localhost:5000/blog-tomcat:1.0"