# 🐳 중소기업용 단일 서버 Kubernetes(k3s) 자동 구성 스크립트

이 저장소는 **중소기업 환경에서 1대의 서버만으로 Rancher, NGINX, Tomcat, MySQL 기반 3-Tier 구조를 손쉽게 구성**할 수 있도록 설계된 자동 설치 스크립트와 설정 파일을 제공합니다.

---

## 📦 구성 요소

| 구성 요소 | 설명 |
|-----------|------|
| `install_k3s_rancher.sh` | Rancher, Helm, k3s, cert-manager를 자동 설치하는 스크립트 |
| `namespace.yaml` | `dev`, `stage`, `prod` 네임스페이스를 생성하는 YAML 파일 |
| `values-nginx-tomcat-mysql.yaml` | NGINX, Tomcat, MySQL을 Helm 기반으로 배포하기 위한 설정 파일 |

---

## 🛠 설치 방법

### 1. 서버 사양 (권장)
- Ubuntu 20.04 이상
- 2vCPU, 4GB RAM, SSD 64GB 이상
- 고정 IP 할당 권장

### 2. 설치 순서

```bash
# 1. 저장소 클론 또는 ZIP 다운로드
git clone https://github.com/tracer999/k3s_rancher_autosetup
cd k3s-rancher-autosetup

# 2. 설치 스크립트 실행
chmod +x install_k3s_rancher.sh
./install_k3s_rancher.sh

# 3. 네임스페이스 생성
kubectl apply -f namespace.yaml

# 4. Helm 배포 예시 (NGINX + Tomcat + MySQL)
helm install webapp -f values-nginx-tomcat-mysql.yaml stable/nginx
```

> 📌 Rancher 설치 후 웹 브라우저에서 `http://<서버 IP>`로 접속하여 GUI 관리 가능 (기본 admin 계정 제공)

---

## 📁 Helm 배포 구성 예시

- **NGINX**: 외부 접근을 위한 프론트엔드 웹 서버
- **Tomcat**: 내부 WAS 컨테이너
- **MySQL**: 애플리케이션 데이터 저장용 DB

모든 구성은 **ClusterIP** 기반으로 설정되어 있어 내부 네트워크에서 서비스 연동이 가능하며, `Ingress` 설정 추가 시 외부 노출도 가능합니다.

---

## 🔒 보안 및 운영 고려사항

- 설치 이후 `bootstrapPassword` 변경 필요
- Traefik 등 Ingress Controller 연동 시 TLS 인증 구성 필요
- RBAC 및 사용자 역할 분리 설정 권장

---

## 🧑‍💻 기여
이 스크립트는 오픈소스이며, 중소기업 디지털 전환을 위한 실용적 구성을 목표로 합니다. 개선 제안 및 PR을 환영합니다.

---

## 📜 라이선스
MIT License



