#!/bin/bash
set +x 2>/dev/null

echo "🧨 k3s 워커 노드 제거 스크립트"
echo "⚠️ 이 작업은 워커 노드에서 k3s-agent 관련 구성과 데이터를 모두 삭제합니다."
read -p "계속하시겠습니까? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "⛔ 작업이 취소되었습니다."
    exit 0
fi

# 1. k3s-agent 언인스톨
if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
    echo "▶️ k3s-agent 언인스톨 중..."
    /usr/local/bin/k3s-agent-uninstall.sh &>/dev/null
    echo "✅ k3s-agent 제거 완료"
else
    echo "ℹ️ k3s-agent는 이미 제거되었거나 설치되지 않았습니다."
fi

# 2. systemd 처리
echo "🧹 systemd 등록 제거..."
systemctl disable k3s-agent &>/dev/null || true
(
  systemctl reset-failed k3s-agent &>/dev/null || true
)
systemctl daemon-reexec &>/dev/null || true
systemctl daemon-reload &>/dev/null || true

# 3. 바이너리 및 링크 제거
echo "🧹 심볼릭 링크 및 실행 파일 정리 중..."
rm -f /usr/local/bin/k3s
rm -f /usr/local/bin/k3s-agent-uninstall.sh
rm -f /usr/local/bin/k3s-killall.sh
rm -f /usr/local/bin/kubectl
rm -f /usr/local/bin/crictl
rm -f /usr/local/bin/ctr

# 4. 디렉토리 제거
echo "🧹 설정 및 데이터 디렉터리 제거 중..."
rm -rf /etc/rancher/k3s
rm -rf /var/lib/kubelet
rm -rf /var/lib/cni/
rm -rf /run/k3s
rm -rf /run/flannel

echo ""
echo "✅ 워커 노드 초기화 완료!"
echo "💡 재등록하려면 install_k3s_worker.sh 를 다시 실행하세요."
