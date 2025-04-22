
# k3s Rancher 자동화 구성 설명서

## 🚀 개요

최근 소프트웨어 개발과 배포 환경은 전통적인 모놀리식 아키텍처(Monolithic Architecture)에서 마이크로서비스 아키텍처(Microservice Architecture, MSA)로 전환되고 있습니다. 이에 따라 운영 환경 역시 VM 기반에서 컨테이너 기반으로 변화하고 있으며, 이를 관리하기 위한 컨테이너 오케스트레이션 도구의 필요성이 증가하고 있습니다.

본 설명서는 복잡한 Kubernetes의 학습 곡선을 줄이고, 간편하게 클러스터 환경을 구축할 수 있도록 k3s를 기반으로 Rancher 및 관련 필수 구성 요소들을 자동화하여 설치하는 방법을 안내합니다.

## 📌 k3s 소개

k3s는 Kubernetes의 경량화 버전으로, 다음과 같은 특징이 있습니다:
- 설치가 쉽고 빠르며, 가벼운 리소스 사용
- 단일 바이너리로 구성되어 복잡성 감소
- Helm, Traefik, Containerd가 기본 내장

## 📦 자동 설치 구성 흐름

### 1️⃣ 마스터 노드 설치

#### 설치 목적
클러스터의 관리를 담당하는 마스터 노드를 구성하며, Rancher, Ingress Controller, Docker Registry 등 핵심 요소들을 자동 설치합니다.

#### 실행 방법
```bash
sudo ./install_k3s_full_stack.sh
```

#### 입력 예시
```
Rancher에서 사용할 도메인 입력: rancher.ydata.co.kr
```

#### 구성 요소
| 단계 | 구성요소 | 상세 설명 |
|------|-----------|-----------|
| 1 | 시스템 패키지 설치 | curl, wget, jq 및 인증서 관리 도구 설치 |
| 2 | k3s 설치 | 경량 쿠버네티스 엔진 |
| 3 | Helm 설치 | Kubernetes 애플리케이션 관리를 위한 패키지 관리자 |
| 4 | Kubeconfig 설정 | kubectl 명령어 사용 환경 설정 |
| 5 | 로컬 스토리지 구성 | 로컬 스토리지 공간 설정 |
| 6 | cert-manager 설치 | 자동 TLS 인증서 관리 |
| 7 | Rancher 설치 | Kubernetes 관리용 웹 인터페이스 |
| 8 | Rancher NodePort 설정 | 외부에서 접근 가능한 포트 설정 |
| 9 | production 네임스페이스 생성 | 실제 서비스 배포용 네임스페이스 |
| 10 | Ingress Controller 설치 | 클러스터 내부 서비스와 외부 연결 처리 |
| 11 | Docker Registry 설치 | 내부 컨테이너 이미지 저장소 설치 (포트 5000) |

### 2️⃣ 워커 노드 설치

#### 설치 목적
마스터 노드와 연결하여 실제 서비스를 실행하는 노드를 구성합니다.

#### 실행 방법
```bash
sudo ./install_k3s_full_stack.sh
```

#### 입력 예시
```
마스터 노드 IP: 192.168.1.100
Join 토큰: K106a...::server:xxxxx
```

### 3️⃣ MySQL 8 배포

#### 설치 목적
애플리케이션 데이터를 저장할 MySQL 데이터베이스 서버 설치 및 설정입니다.

#### 실행 방법
```bash
sudo ./install_mysql8.sh
```

#### 입력 예시
```
생성할 DB 이름: mydb
DB 사용자 이름: user01
DB 비밀번호: yourpassword
MySQL 서비스 이름: mysql-svc
```

### 4️⃣ Tomcat10 배포

#### 설치 목적
웹 애플리케이션을 배포하고 실행하는 Tomcat 서버를 구성합니다.

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

#### 설치 목적
클러스터 내부 서비스와 외부 도메인을 연결하고, SSL/TLS 보안을 적용합니다.

#### 실행 방법
```bash
sudo ./install_ingress-nginx.sh
```

#### 입력 예시
```
내부 서비스 주소: http://blog-tomcat.production.svc.cluster.local:8080
도메인 입력: blog.example.com
```

## ✨ 구성 완료 후 기대 효과
- Git을 통한 간편한 자동화 배포
- Rancher 웹 UI를 통한 간편한 클러스터 관리
- 외부 서비스 접근 및 TLS 보안 강화

## 🗂️ 참고 스크립트 목록
| 구성 항목 | 스크립트 파일 |
|-----------|--------------|
| 마스터/워커 노드 설치 | install_k3s_full_stack.sh |
| MySQL 설치 | install_mysql8.sh |
| Tomcat10 배포 | install_tomcat10.sh |
| Ingress 및 인증서 구성 | install_ingress-nginx.sh |

## 🚧 향후 확장 방안
- GitHub Actions 또는 Jenkins를 통한 CI/CD 구축
- Argo CD를 이용한 GitOps 환경 구성
- Prometheus 및 Grafana를 활용한 모니터링 시스템 구축
- 인증서 자동 갱신 관리 도입

이 구성은 Kubernetes 인프라를 간편히 구축하고 운영할 수 있는 효율적인 자동화 방안입니다.
