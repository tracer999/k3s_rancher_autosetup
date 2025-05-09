🌐 Language: [한국어](./README.md) | [English](./README_en.md) | [日本語](./README_ja.md) | [Español](./README_es.md)

# ⚙️ k3s 기반 경량 Kubernetes 클러스터 자동 설치 스크립트 모음

## 📌 개요

이 저장소는 **경량 쿠버네티스 배포판인 k3s**를 기반으로 한 마스터-워커 구조의 클러스터를 손쉽게 구축하고, MySQL, Tomcat, Ingress, NFS 등의 서비스를 자동으로 설치·운영하기 위한 **쉘 스크립트 모음**입니다.

- 기본 구성: 마스터 노드 1대, 워커 노드 1대
- 워커 노드는 필요에 따라 **추가 확장 가능**
- 웹 애플리케이션 실행에 필요한 Tomcat 및 공유 스토리지(NFS) 자동 구성
- 자체 인증서를 활용한 HTTPS Ingress 구성 지원

---

## 📂 설치 순서 요약

### 1️⃣ `install_k3s_full_stack.sh` — 마스터 및 워커 노드 설치

- 마스터/워커 공용 스크립트입니다.
- 마스터 노드에서는 Rancher, Ingress Controller, Docker Registry, cert-manager 등을 자동 설치합니다.
- 워커 노드는 마스터 IP 및 join token을 입력하여 클러스터에 합류합니다.

```bash
# 마스터 또는 워커에서 실행
sudo ./install_k3s_full_stack.sh
```

### 2️⃣ `install_mysql8.sh` — MySQL 8 설치

- Helm 차트를 이용해 `production` 네임스페이스에 MySQL을 배포합니다.
- 초기 SQL 덤프가 `deploy/mysql/init-sql/database_dump.sql`에 있으면 자동 반영됩니다.
- 결과적으로 내부 또는 외부에서 접근 가능한 MySQL 서비스를 생성합니다.

```bash
sudo ./install_mysql8.sh
```

### 3️⃣ `setup_nfs_and_pv.sh` — NFS 서버 설치 및 PV/PVC 생성

- 마스터 노드에서 NFS 서버를 설치하고, 공유 폴더를 설정합니다.
- Kubernetes에서 접근 가능한 PersistentVolume 및 PersistentVolumeClaim 리소스를 자동 생성합니다.

```bash
sudo ./setup_nfs_and_pv.sh
```

> 생성된 YAML 파일은 `pv_pvc_yaml/` 디렉토리에 저장됩니다.

### 4️⃣ `install_tomcat10.sh` — Tomcat10 컨테이너 배포

- 공유 PVC가 마운트된 Tomcat10 Pod를 배포합니다.
- Dockerfile은 `deploy/tomcat10/` 내부에 있으며, `ROOT.war` 파일이 있어야 합니다.
- Docker 이미지 빌드 후 로컬 레지스트리에 푸시되어 사용됩니다.

```bash
sudo ./install_tomcat10.sh
```

> `31808` 포트를 통해 외부에서 Tomcat에 접속 가능합니다.

### 5️⃣ `install_ingress-nginx.sh` — Ingress 및 인증서 적용

- 사전에 `certs/server.crt.pem`, `server.key.pem`이 준비되어 있어야 합니다.
- 입력된 도메인에 대해 Ingress 리소스를 생성하고 HTTPS를 자동 설정합니다.

```bash
sudo ./install_ingress-nginx.sh
```

> 생성된 인증서는 Secret 리소스로 등록되며, nginx Ingress Controller를 통해 TLS 적용됨.

---

## ❌ 클러스터 제거

### `uninstall_k3s_full_stack.sh`

- 설치된 Rancher, Registry, cert-manager, ingress-nginx 등을 모두 삭제합니다.
- 마스터/워커 노드에서 각각 실행 가능하며, Node 선택 메뉴가 제공됩니다.

```bash
sudo ./uninstall_k3s_full_stack.sh
```

---

## 🗂️ 스크립트 구성 요약

| 기능 | 스크립트 파일 |
|------|-------------------------|
| k3s + Rancher 설치 | install_k3s_full_stack.sh |
| MySQL 8 설치 | install_mysql8.sh |
| NFS 및 PV/PVC 설정 | setup_nfs_and_pv.sh |
| Tomcat10 배포 | install_tomcat10.sh |
| Ingress 및 인증서 설정 | install_ingress-nginx.sh |
| 클러스터 제거 | uninstall_k3s_full_stack.sh |

---

## 📁 기타 디렉토리

- `deploy/mysql/init-sql/`: 초기 데이터베이스 SQL 파일
- `deploy/tomcat10/`: Tomcat Dockerfile, ROOT.war 포함 위치
- `certs/`: HTTPS 인증서 파일 위치 (`server.crt.pem`, `server.key.pem`)
- `pv_pvc_yaml/`: PV 및 PVC 정의 YAML 저장 폴더

---

## 👨‍💻 개발

- 제작: 단국대학교 정보융합기술·창업대학원 실습 기반 프로젝트
- 대상: k3s를 기반으로 한 Kubernetes 환경을 **직접 구성하고자 하는 실무자 및 연구자**

---

## 📌 비고

- 본 프로젝트는 개발 및 실습용으로 구성되어 있으며, 운영환경에서는 추가 보안 설정이 필요할 수 있습니다.
- 인증서 자동 갱신, 백업 정책, 장애 복구 시나리오 등은 별도로 구현되어야 합니다.
