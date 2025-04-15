#!/bin/bash

echo "🧨 k3s 워커 노드 제거 스크립트"
echo "⚠️ 이 작업은 워커 노드에서 k3s-agent 관련 구성과 데이터를 모두 삭제합니다."
echo "계속하시겠습니까? (y/n)"
read -r confirm
if [[ "$confirm" != "y" ]]; then
    echo "⛔ 작업이 취소되었습니다."
    exit 0
fi

# 에이전트 언인스톨 스크립트 실행
if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
    echo "▶️ k3s-agent 언인스톨 중..."
    sudo /usr/local/bin/k3s-agent-uninstall.sh
    echo "✅ k3s-agent 제거 완료"
else
    echo "⚠️ /usr/local/bin/k3s-agent-uninstall.sh 파일이 없습니다. 이미 제거되었거나 설치되지 않았을 수 있습니다."
fi

# 불필요한 심볼릭 링크 정리
echo "🧹 심볼릭 링크 정리 중..."
sudo rm -f /usr/local/bin/kubectl 2>/dev/null

echo ""
echo "✅ 워커 노드 초기화 완료"
echo "💡 재등록하려면 install_k3s_worker.sh 를 다시 실행하세요."
