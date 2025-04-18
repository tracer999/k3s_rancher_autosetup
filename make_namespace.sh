#!/bin/bash
echo "[1/1] 네임스페이스 생성: production"
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
echo "네임스페이스 'production' 생성 완료"
