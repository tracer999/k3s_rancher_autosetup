#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

RECORD_FILE="./deploy/ingress_records.txt"
if [[ ! -f "$RECORD_FILE" ]]; then
  echo "❌ ingress_records.txt 파일이 존재하지 않습니다. 먼저 설치 스크립트를 실행하세요."
  exit 1
fi

echo "📜 현재 등록된 Ingress 기록:"
nl "$RECORD_FILE"
echo ""

read -p "삭제할 항목의 도메인 입력 (예: blog.example.com): " DOMAIN_NAME
if [[ -z "$DOMAIN_NAME" ]]; then
  echo "❌ 도메인은 필수입니다."
  exit 1
fi

# 해당 도메인의 기록 추출
MATCHED_LINE=$(grep "DOMAIN=$DOMAIN_NAME\b" "$RECORD_FILE" || true)
if [[ -z "$MATCHED_LINE" ]]; then
  echo "❌ 해당 도메인의 Ingress 설정이 존재하지 않습니다."
  exit 1
fi

# 포트 및 인그레스명 추출
EXTERNAL_PORT=$(echo "$MATCHED_LINE" | grep -oE 'PORT=[0-9]+' | cut -d= -f2)

echo "🗑️ 다음 리소스를 삭제합니다:"
echo "   ▸ Ingress: ingress-$EXTERNAL_PORT"
echo "   ▸ Secret : tls-$EXTERNAL_PORT"
echo ""

read -p "계속 진행하시겠습니까? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "❎ 삭제가 취소되었습니다."
  exit 0
fi

# 리소스 삭제
kubectl delete ingress ingress-$EXTERNAL_PORT -n production --ignore-not-found
kubectl delete secret tls-$EXTERNAL_PORT -n production --ignore-not-found

# 기록에서 제거
grep -v "DOMAIN=$DOMAIN_NAME\b" "$RECORD_FILE" > "$RECORD_FILE.tmp" && mv "$RECORD_FILE.tmp" "$RECORD_FILE"

echo "✅ 삭제 완료: $DOMAIN_NAME (포트 $EXTERNAL_PORT)"
