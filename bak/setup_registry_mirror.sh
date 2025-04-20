#!/bin/bash
set -e

echo "🔧 마스터 레지스트리 미러 설정 (docker.io 는 건드리지 않음)"

read -p "📡 마스터 노드의 IP 주소를 입력하세요 (레지스트리 실행 중): " MASTER_IP

CONFIG_PATH="/etc/rancher/k3s/registries.yaml"

sudo mkdir -p /etc/rancher/k3s
cat <<EOF | sudo tee $CONFIG_PATH > /dev/null
mirrors:
  "$MASTER_IP:5000":
    endpoint:
      - "http://$MASTER_IP:5000"
EOF

echo "✅ 설정 완료! 반드시 'docker.io'는 설정하지 않아야 MySQL 등 외부 이미지가 정상 작동합니다."
