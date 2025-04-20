#!/bin/bash
set -e

# 색상 설정
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

clear
echo -e "${YELLOW}⚠️  k3s 클러스터 완전 삭제 스크립트 (v2)${NC}"
echo -e "${YELLOW}⚠️  삭제 전에 반드시 백업을 완료했는지 확인하세요!${NC}"
echo "1) 마스터 노드에서 삭제"
echo "2) 워커 노드에서 삭제"
read -p "어떤 노드에서 삭제하시겠습니까? (1 or 2): " mode

read -p "정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다. (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo -e "${RED}❌ 삭제가 취소되었습니다.${NC}"
  exit 1
fi

if [[ "$mode" == "1" ]]; then
  echo -e "${GREEN}🧨 마스터 노드 클러스터 전체 삭제 시작...${NC}"

  # 모든 워커 노드 강제 제거
  echo "🔍 연결된 노드 목록 확인 및 제거"
  nodes=$(sudo kubectl get nodes --no-headers | awk '{print $1}')
  for node in $nodes; do
    echo "❌ 노드 제거: $node"
    sudo kubectl delete node "$node" --ignore-not-found || true
  done

  # k3s, Rancher, Ingress, Registry 등 관련 서비스 중지 및 삭제
  echo "🧹 k3s 서비스 제거"
  sudo systemctl stop k3s || true
  sudo /usr/local/bin/k3s-uninstall.sh || true

  echo "🧹 Registry 컨테이너 제거"
  docker rm -f registry || true
  sudo rm -rf /opt/registry /var/lib/rancher/k3s /etc/rancher /etc/kubernetes ~/.kube ~/.config/k3s || true

  echo "🧹 남은 k3s 디렉토리 정리"
  sudo rm -rf /var/lib/kubelet /var/lib/etcd /etc/cni /opt/cni /run/flannel /run/k3s /etc/systemd/system/k3s* || true

  echo -e "${GREEN}✅ 마스터 노드 관련 파일 및 리소스 모두 삭제 완료${NC}"

elif [[ "$mode" == "2" ]]; then
  echo -e "${GREEN}🧨 워커 노드에서 k3s 제거 시작...${NC}"

  echo "🧹 k3s-agent 서비스 중지 및 제거"
  sudo systemctl stop k3s-agent || true
  sudo /usr/local/bin/k3s-agent-uninstall.sh || true

  echo "🧹 디렉토리 정리"
  sudo rm -rf /var/lib/rancher/k3s /etc/rancher /etc/kubernetes /etc/cni /opt/cni /run/flannel /run/k3s || true

  echo -e "${GREEN}✅ 워커 노드 관련 리소스 삭제 완료${NC}"

else
  echo -e "${RED}❌ 잘못된 선택입니다. 1 또는 2를 입력하세요.${NC}"
  exit 1
fi

echo -e "\n${GREEN}🎉 클러스터 삭제가 완료되었습니다.${NC}"
