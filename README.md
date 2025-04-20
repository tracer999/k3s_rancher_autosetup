# k3s Rancher 자동화 구성 - 3 Tier 환경

이 저장소는 경량 쿠버네티스 `k3s` 기반으로 중소기업에서도 쉽게 사용할 수 있도록 설계된 3 Tier 웹 애플리케이션 인프라 자동화 구성 도구입니다.

구성 요소:
- `Tomcat 10` (Frontend Application)
- `MySQL 8` (Backend Database)
- `MetalLB` + `Ingress` (HTTPS 인증서 기반 외부 노출)
- `Rancher` 웹 UI (k8s 리소스 관리)

---

## 🛠 설치 순서

### 1. **k3s 클러스터 설치 (마스터 및 워커 노드)**
```bash
./install_k3s_full_stack.sh
```
- 실행 시 마스터 설치(1) 또는 워커 설치(2) 중 선택 가능

#### 마스터 노드 설치 시 구성 요소
- k3s 서버 설치 및 kubeconfig 설정
- Helm 3 설치
- cert-manager 설치 (인증서 관리)
- Rancher 설치 (웹 기반 K8s 관리 UI)
  - 설치 후 `NodePort` 로 노출되며 접속 주소는 출력됨
  - 초기 관리자 ID: `admin`, 초기 비밀번호: `admin`
- production 네임스페이스 생성
- 로컬 Docker Registry 설치 (`5000 포트`)
- 마스터 노드 IP 자동 저장 (`~/registry_ip`)

#### 워커 노드 설치 시 기능
- 마스터 IP, 토큰 입력으로 클러스터에 자동 연결
- 로컬 Registry에 연결되도록 `/etc/rancher/k3s/registries.yaml` 자동 설정
- 스크립트를 원하는 수의 워커 노드에서 실행하여 확장 가능

### 2. **MySQL 8 배포**
```bash
./install_mysql8.sh
```
- 사용자로부터 DB명, 계정명, 비밀번호, 서비스명을 입력받아 설정
- Helm Chart (`bitnami/mysql`) 기반으로 설치됨
- 기본 포트는 `31060` (NodePort)
- 내부 접근 DNS 예: `service-name.production.svc.cluster.local:3306`
- `deploy/mysql/init-sql/database_dump.sql` 파일을 초기 스크립트로 자동 실행
- 설치가 완료되면 접속 정보와 노드 정보 출력됨

삭제 시:
```bash
./delete_helm_release.sh
```
- Helm 기반으로 배포된 MySQL 제거

### 3. **Tomcat 인스턴스 배포**
```bash
./install_tomcat.sh
```
- 공통 서비스명 예: `blog-tomcat`, `bbs-tomcat`
- Tomcat 인스턴스 수 입력 (예: 3 입력 시 `blog-tomcat-1~3` 생성)

> 💡 기능 설명:
> - 해당 스크립트는 `deploy/tomcat10/Dockerfile`을 기반으로 Tomcat 10 + Java 21 환경을 생성합니다.
> - 기본 베이스 이미지: `eclipse-temurin:21-jdk`
> - Tomcat 10.1.40 버전 설치
> - `deploy/tomcat10/ROOT.war` 파일을 `/webapps/ROOT.war` 위치로 자동 복사
> - 개발자는 Dockerfile을 수정하여 자신만의 WAR, 환경변수, 미들웨어 구성 가능
> - 각 인스턴스는 NodePort로 노출되며 포트는 자동 지정됨
> - 공통 접근용 ClusterIP 서비스 (`blog-tomcat.production.svc.cluster.local`) 생성

### 4. **MetalLB + HTTPS 연동 (Ingress)**
```bash
./install_metallb_ssl.sh
```
- 연결할 내부 서비스 주소 입력 (예: `http://blog-tomcat.production.svc.cluster.local:8080`)
- 외부에서 노출할 포트 입력 (예: `443`)
- 접근할 도메인 입력 (예: `blog.example.com`)
- TLS 인증서 (`server.all.crt.pem`, `server.key.pem`)를 `certs/` 경로에 위치시켜 사용
- Ingress Controller(NGINX)가 없으면 자동 설치됨
- MetalLB와 함께 외부 트래픽을 받아 Ingress로 전달
- 외부에서 인증서가 적용된 주소로 서비스 접근 가능

삭제 시:
```bash
./delete_metallb_ssl.sh
```

---

## 🧹 삭제 스크립트

### Tomcat 그룹 전체 삭제
```bash
./delete_tomcat.sh
```
- 서비스명 입력 (예: `blog-tomcat`)
- 해당 그룹의 모든 Deployment, Service, ClusterIP 일괄 삭제

### 개별 K8s 리소스 삭제
```bash
./delete_k8s_service.sh
```

### Helm 설치 리소스 삭제
```bash
./delete_helm_release.sh
```

### Ingress Controller 및 MetalLB 구성 삭제
```bash
./delete_ingress_nginx.sh
./delete_metallb_ssl.sh
```

---

## 📁 디렉토리 구조 요약

```bash
certs/                 👉 TLS 인증서 (.crt.pem, .key.pem)
deploy/
  ├── mysql/           👉 초기 SQL 스크립트 포함
  └── tomcat10/        👉 Dockerfile + ROOT.war
install_k3s_full_stack.sh      👉 k3s + Rancher + Registry 설치
install_mysql8.sh              👉 MySQL 8 자동 배포
install_tomcat.sh              👉 여러 Tomcat 인스턴스 배포
install_metallb_ssl.sh         👉 Ingress + MetalLB + TLS 자동 구성
delete_metallb_ssl.sh          👉 MetalLB + Ingress 구성 삭제
delete_tomcat.sh               👉 Tomcat 인스턴스 일괄 삭제
delete_helm_release.sh         👉 Helm 리소스 삭제 스크립트
delete_k8s_service.sh          👉 특정 K8s 리소스 삭제
```

---

## ✅ 예시 접속 방식

- 내부 접속: `http://blog-tomcat.production.svc.cluster.local:8080`
- 외부 접속: `https://blog.example.com:443`

---

## 🌐 Rancher Web UI 접속 안내

- 설치 후 NodePort 서비스로 노출됨
- 접속 주소는 마스터 노드 설치 완료 시 출력됨 (예: `http://<마스터 IP>:<NodePort>`)
- 초기 ID: `admin`, 비밀번호: `admin`

기능:
- Kubernetes 리소스 확인 및 편집
- Deployment, Service, ConfigMap 생성
- Pod 상태, 로그, 이벤트 확인
- 네임스페이스 및 Helm Chart 관리

---

## 🙋‍♂️ 기타 안내

- Pod 수 늘리려면 `./install_tomcat.sh` 재실행
- 인증서 교체 후 `install_metallb_ssl.sh` 재실행
- 모든 구성은 로컬 Docker 이미지로 작동하므로, 인터넷 없이도 동일한 WAR 파일을 다양한 서버에 배포 가능

---

