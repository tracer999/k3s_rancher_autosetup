🌐 Language: [한국어](./README.md) | [English](./README_en.md) | [日本語](./README_ja.md) | [Español](./README_es.md)

# ⚙️ Lightweight Kubernetes Cluster Automation with k3s

## 📌 Overview

This repository provides a collection of **automation shell scripts** for deploying a lightweight Kubernetes cluster using **k3s**, along with key components such as MySQL, Tomcat, Ingress, and NFS.

- Default configuration: 1 master node and 1 worker node
- Easily scalable by adding more worker nodes
- Includes web application stack (Tomcat + shared NFS storage)
- SSL/TLS with custom certificates via Ingress support

---

## 🧭 Installation Workflow

### 1️⃣ `install_k3s_full_stack.sh` — Install Master / Worker Node

- Common script for both master and worker nodes
- Installs Rancher, Ingress Controller, Docker Registry, and cert-manager on the master node
- Joins worker node to the cluster using master IP and token

```bash
# Run on both master and worker nodes
sudo ./install_k3s_full_stack.sh
```

---

### 2️⃣ `install_mysql8.sh` — Deploy MySQL 8

- Deploys MySQL via Helm into the `production` namespace
- Initial SQL dump from `deploy/mysql/init-sql/database_dump.sql` is automatically applied if present

```bash
sudo ./install_mysql8.sh
```

---

### 3️⃣ `setup_nfs_and_pv.sh` — Set Up NFS and Create PV/PVC

- Installs an NFS server on the master node and configures a shared directory
- Automatically generates PersistentVolume and PersistentVolumeClaim resources

```bash
sudo ./setup_nfs_and_pv.sh
```

> The generated YAML files are saved under `pv_pvc_yaml/`.

---

### 4️⃣ `install_tomcat10.sh` — Deploy Tomcat10 Container

- Deploys a Tomcat10 Pod mounted with the shared PVC
- Dockerfile is located in `deploy/tomcat10/` and requires a `ROOT.war` file
- Builds and pushes the image to the local Docker Registry

```bash
sudo ./install_tomcat10.sh
```

> Tomcat will be accessible via NodePort 31808.

---

### 5️⃣ `install_ingress-nginx.sh` — Setup Ingress and SSL

- Requires `certs/server.crt.pem` and `server.key.pem` files to be pre-configured
- Generates Ingress resource for the given domain and enables HTTPS via TLS

```bash
sudo ./install_ingress-nginx.sh
```

---

## ❌ Uninstall / Clean-up

### `uninstall_k3s_full_stack.sh`

- Removes all components including Rancher, cert-manager, Ingress, Docker Registry
- Supports both master and worker node removal with menu selection
- Cleans up namespaces, finalizers, registry settings, and services

```bash
sudo ./uninstall_k3s_full_stack.sh
```

---

## 📁 Script Summary

| Purpose               | Script File Name              |
|----------------------|-------------------------------|
| Install k3s + Rancher | install_k3s_full_stack.sh     |
| Install MySQL 8       | install_mysql8.sh             |
| Setup NFS + PV/PVC    | setup_nfs_and_pv.sh           |
| Deploy Tomcat10       | install_tomcat10.sh           |
| Setup Ingress + SSL   | install_ingress-nginx.sh      |
| Full Uninstall        | uninstall_k3s_full_stack.sh   |

---

## 📂 Directory Overview

- `deploy/mysql/init-sql/`: Initial SQL dump for database
- `deploy/tomcat10/`: Dockerfile and ROOT.war for Tomcat
- `certs/`: SSL certificates (`server.crt.pem`, `server.key.pem`)
- `pv_pvc_yaml/`: YAML files for PV and PVC

---

## 👨‍💻 Development & Purpose

- Developed as part of a practical Kubernetes project at Dankook University, Graduate School of ICT Convergence
- Intended for engineers or researchers building lightweight Kubernetes infrastructure

---

This automation suite is designed to **quickly and efficiently deploy a fully functional k3s-based Kubernetes cluster**, especially for small teams, education, or prototype services.
