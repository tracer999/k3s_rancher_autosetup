#!/bin/bash

echo "[1/3] 시스템 업데이트 및 필수 패키지 설치"
sudo apt update && sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo "[2/3] K3s 워커 노드 등록 정보 입력"
read -p "Master 서버 IP를 입력하세요: " MASTER_IP
read -p "Master 노드에서 받은 Join Token을 입력하세요: " TOKEN

echo "[3/3] K3s 에이전트 설치"
curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN sh -

echo "✅ 워커 노드 등록 완료!"

