# k3s Rancher 자동화 구성 - 3 Tier 환경

이 저장소는 경량 쿠버네티스 `k3s` 기반으로 중소기업에서도 쉽게 사용할 수 있도록 설계된 3 Tier 웹 애플리케이션 인프라 자동화 구성 도구입니다.

## 구성 요소
- `Tomcat 10` (Frontend Application)
- `MySQL 8` (Backend Database)
- `MetalLB` + `Ingress` (HTTPS 인증서 기반 외부 노출)
- `Rancher` 웹 UI (k8s 리소스 관리)

---

## 🛠 설치 순서

### 1. **k3s 클러스터 설치 (마스터 및 워커 노드)**
```bash
./install_k3s_full_stack_v2.sh
```
- 마스터 설치 또는 워커 설치 중 선택 가능
- Rancher 도메인 및 포트 입력 가능
- Ingress Controller까지 자동 설치됨

#### 마스터 노드 설치 시 구성 요소
- `k3s`, `Helm`, `cert-manager`, `Ingress Controller`, `Rancher` 설치
- Rancher는 입력한 도메인으로 Ingress를 통해 HTTPS 노출 가능
- 로컬 Docker Registry 구성 (`5000` 포트)
- 네임스페이스 생성: `production`, `cattle-system`

#### 워커 노드 설치 시
- 마스터 IP와 토큰을 입력받아 클러스터에 자동 연결
- 로컬 Registry 미러 설정 `/etc/rancher/k3s/registries.yaml`
- 원하는 수의 워커 노드에 반복 실행 가능

### 2. **MySQL 8 배포**
```bash
./install_mysql8.sh
```
- DB명, 사용자, 비밀번호, 서비스명을 입력
- 초기 SQL: `deploy/mysql/init-sql/database_dump.sql`
- Helm Chart(`bitnami/mysql`) 기반
- 기본 노출 포트: `31060` (NodePort)

삭제:
```bash
./delete_helm_release.sh
```

### 3. **Tomcat 인스턴스 배포**
```bash
./install_tomcat.sh
```
- 공통 서비스명 예: `blog-tomcat`, `bbs-tomcat`
- 인스턴스 수 입력 시 `-1`, `-2`, `-3` 형태로 생성

> 💡 해당 스크립트는 `deploy/tomcat10/Dockerfile`을 기반으로 `Tomcat 10 + Java 21` 환경을 구성합니다.
> - `ROOT.war`는 `deploy/tomcat10/ROOT.war`에 위치
> - 사용자 정의 Dockerfile/WAR 파일로 쉽게 교체 가능
> - 배포 시 `NodePort` 서비스로 자동 노출됨

삭제:
```bash
./delete_tomcat.sh
```

### 4. **Ingress + MetalLB + HTTPS 도메인 연결**
```bash
./install_metallb_ssl.sh
```
- 내부 Service 주소 + 도메인 + 포트 입력
- 인증서는 `/certs/server.all.crt.pem`, `/certs/server.key.pem` 사용
- `Ingress + Secret + Routing` 모두 자동 설정
- 포트 중복 없이 여러 도메인 구성 가능 (`443`, `8443` 등)

삭제:
```bash
./delete_metallb_ssl.sh
```

---

## 🧹 클러스터 전체 삭제 스크립트

```bash
./uninstall_k3s_full_stack_v2.sh
```
- 마스터/워커 중 선택
- 마스터는 클러스터 전체 + Registry 삭제
- 워커는 `k3s-agent`만 삭제
- 안전 확인을 위해 사용자 입력 요구

---

## 📁 디렉토리 구조 요약

```bash
certs/                        👉 TLS 인증서 디렉토리
deploy/
  ├── mysql/                  👉 초기 database_dump.sql 포함
  └── tomcat10/               👉 Tomcat Dockerfile + ROOT.war
install_k3s_full_stack_v2.sh       👉 전체 구성 설치 (마스터/워커)
uninstall_k3s_full_stack_v2.sh     👉 전체 구성 삭제
install_mysql8.sh                  👉 MySQL 배포
install_tomcat.sh                  👉 Tomcat 다중 배포
install_metallb_ssl.sh             👉 Ingress + 인증서 + 포트 연동
delete_metallb_ssl.sh              👉 Ingress 구성 삭제
delete_tomcat.sh                   👉 Tomcat 일괄 삭제
delete_helm_release.sh             👉 Helm 설치 제거
delete_k8s_service.sh              👉 수동 리소스 제거
```

---

## ✅ 접속 예시

- 내부 접속: `http://blog-tomcat.production.svc.cluster.local:8080`
- 외부 접속: `https://blog.ydata.co.kr:443`

---

## 🌐 Rancher Web UI 접속

- 도메인 입력 시 `https://rancher.ydata.co.kr:443` 과 같이 HTTPS로 접근
- 초기 ID: `admin`, 비밀번호: `admin`
- 기능:
  - K8s 리소스 배포/삭제/모니터링
  - Helm Chart 관리
  - Pod 상태, 로그, 노드 상태 시각화

---

## 🙋‍♂️ 기타 안내

- 인증서 없이도 설치 가능 → 추후 `install_metallb_ssl.sh`로 연결
- 동일한 WAR 파일을 여러 서버에 손쉽게 배포
- NodePort 서비스는 테스트용, 운영은 HTTPS(443) 사용 권장
