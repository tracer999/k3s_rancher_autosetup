
# k3s Rancher 자동화 구성 안내서

## 🚀 개요

최근 소프트웨어 개발 및 배포 환경은 전통적인 모놀리식 아키텍처(Monolithic Architecture)에서 마이크로서비스 아키텍처(MSA)로 전환되고 있습니다. 이에 따라 운영 환경 또한 가상머신(VM)에서 컨테이너 기반 환경으로 이동하면서 컨테이너 오케스트레이션 도구에 대한 수요가 증가하고 있습니다.

이 안내서는 Kubernetes의 복잡성을 줄이고 경량화된 배포판인 k3s를 이용하여 Kubernetes 클러스터 구축을 손쉽게 할 수 있도록, Rancher 및 필수 구성 요소의 설치를 자동화하는 방법을 설명합니다.

## 📌 k3s 소개

k3s는 다음과 같은 특징을 가진 경량 Kubernetes 배포판입니다:
- 빠르고 쉬운 설치와 적은 리소스 사용
- 단일 바이너리 구성으로 복잡성 감소
- Helm, Traefik, Containerd 기본 내장

## ✅ 사전 준비 사항

- AWS 클라우드 환경 기준으로 최소 `t2.medium` 이상의 스펙을 가진 VM 2대 또는 동일 사양의 온프레미스 서버 2대가 필요합니다. 하나의 마스터 노드로 다수의 워커 노드 구성이 가능합니다.

## 📦 자동 설치 구성 흐름

### 1️⃣ 마스터 노드 설치

#### 목적
마스터 노드는 Kubernetes 클러스터를 관리합니다. 이 스크립트는 Rancher, Ingress Controller, Docker Registry 등의 필수 요소를 자동 설치합니다.

#### 실행 방법
```bash
sudo ./install_k3s_full_stack.sh
```

#### 입력 예시
```
Rancher에서 사용할 도메인 입력: rancher.ydata.co.kr
```

### 2️⃣ 워커 노드 설치

#### 목적
마스터 노드에 연결되어 실제 서비스를 실행하는 워커 노드를 설치합니다.

#### 실행 방법
```bash
sudo ./install_k3s_full_stack.sh
```

#### 입력 예시
```
마스터 노드 IP: 192.168.1.100
Join 토큰: K106a...::server:xxxxx
```

### 3️⃣ MySQL 8 설치

#### 목적
애플리케이션 데이터 저장을 위한 MySQL 데이터베이스를 설치합니다. 별도의 VM 기반 DB 사용을 권장하지만, 컨테이너 기반 설치가 필요한 경우 이 스크립트를 사용할 수 있습니다.

#### 실행 방법
```bash
sudo ./install_mysql8.sh
```

#### 입력 예시
```
DB 이름: mydb
DB 사용자 이름: user01
DB 비밀번호: yourpassword
MySQL 서비스 이름: mysql-svc
```

### 4️⃣ Tomcat10 배포

#### 목적
웹 애플리케이션을 배포하는 Tomcat 서버를 설치합니다. 이 스크립트는 `deploy/tomcat10/Dockerfile`을 참조하여 Docker 이미지를 만들고, 마스터 노드에 설치된 Registry에 저장한 후 이를 기반으로 컨테이너(POD)를 배포합니다. 여러 인스턴스를 설치하여 내부 로드밸런싱을 구성할 수 있습니다.

**주의:** 제공된 Dockerfile은 Tomcat과 연동할 `ROOT.war` 파일이 필요합니다.

#### 실행 방법
```bash
sudo ./install_tomcat10.sh
```

#### 입력 예시
```
서비스 이름 입력: blog-tomcat
배포할 인스턴스 수: 2
```

### 5️⃣ Ingress 및 인증서 구성

#### 목적
클러스터 내부 서비스와 외부 도메인을 연결하며 SSL/TLS 보안을 설정합니다.

**중요:** `certs/server.crt.pem`과 `certs/server.key.pem` 인증서 파일이 반드시 있어야 합니다.

#### 실행 방법
```bash
sudo ./install_ingress-nginx.sh
```

#### 입력 예시
```
내부 서비스 주소: http://blog-tomcat.production.svc.cluster.local:8080
도메인 입력: blog.example.com
```

### 🗑️ 삭제 방법

클러스터 전체 삭제가 필요한 경우, 제공된 스크립트를 실행합니다:

```bash
sudo ./uninstall_k3s_full_stack.sh
```

선택 옵션:
```
1) 마스터 노드 삭제
2) 워커 노드 삭제
```

## ✨ 기대 효과
- Git을 통한 간편한 자동화 배포
- Rancher 웹 UI를 통한 쉬운 클러스터 관리
- 외부 서비스 접근과 TLS를 통한 보안 강화

## 🗂️ 참조 스크립트
| 구성 항목 | 스크립트 파일 |
|---------------|-------------|
| 마스터/워커 노드 설치 | install_k3s_full_stack.sh |
| MySQL 설치 | install_mysql8.sh |
| Tomcat10 배포 | install_tomcat10.sh |
| Ingress 및 인증서 구성 | install_ingress-nginx.sh |
| 클러스터 삭제 | uninstall_k3s_full_stack.sh |

## 🚧 향후 확장 방향
- GitHub Actions 또는 Jenkins를 활용한 CI/CD 구축
- Argo CD를 활용한 GitOps 배포
- Prometheus 및 Grafana를 통한 모니터링 구축
- 인증서 자동 갱신 관리

---

## 📌 제작
단국대학교 정보융합기술·창업대학원에서 개발 🇰🇷

---

본 자동화 구성은 Kubernetes 인프라를 쉽고 빠르게 구축하고 운영할 수 있는 효율적이고 실용적인 방법을 제공합니다.
