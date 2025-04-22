
# k3s Rancher Automation Setup Guide

## 🚀 Overview

Recently, software development and deployment environments are shifting from traditional Monolithic Architecture to Microservice Architecture (MSA). Consequently, operational environments are also transitioning from virtual machines (VMs) to container-based solutions, increasing the demand for container orchestration tools.

This guide aims to simplify the learning curve associated with Kubernetes by using k3s, a lightweight Kubernetes distribution. It automates the setup of Rancher and other essential components required for creating and managing Kubernetes clusters.

## 📌 Introduction to k3s

k3s is a lightweight Kubernetes distribution offering the following key features:
- Quick and easy installation with minimal resource usage
- Single binary for simplicity and reduced complexity
- Built-in Helm, Traefik, and Containerd

## ✅ Prerequisites

- Two VMs on AWS Cloud with specifications equal to or greater than `t2.medium`, or two on-premise servers with equivalent specs. You can configure multiple worker nodes with a single master node.

## 📦 Automated Installation Workflow

### 1️⃣ Master Node Installation

#### Purpose
The master node manages the Kubernetes cluster. This script automates the installation of Rancher, Ingress Controller, Docker Registry, and other essential components.

#### How to Run
```bash
sudo ./install_k3s_full_stack.sh
```

#### Input Example
```
Enter domain for Rancher: rancher.example.com
```

#### Components
| Step | Component | Description |
|------|-----------|-------------|
| 1 | System packages | Install curl, wget, jq, and certificate tools |
| 2 | k3s installation | Lightweight Kubernetes engine |
| 3 | Helm installation | Package manager for Kubernetes |
| 4 | Kubeconfig setup | Configure kubectl environment |
| 5 | Local storage | Configure local storage for volumes |
| 6 | cert-manager | Automatic TLS certificate management |
| 7 | Rancher installation | Kubernetes web-based management UI |
| 8 | Rancher NodePort setup | Configure external access ports |
| 9 | Production namespace | Namespace for deploying applications |
| 10 | Ingress Controller | Manages external access to internal services |
| 11 | Docker Registry | Local container image storage (port 5000) |

### 2️⃣ Worker Node Installation

#### Purpose
Setup worker nodes that connect to the master node and run the application services.

#### How to Run
```bash
sudo ./install_k3s_full_stack.sh
```

#### Input Example
```
Master Node IP: 192.168.1.100
Join Token: K106a...::server:xxxxx
```

### 3️⃣ MySQL 8 Deployment

#### Purpose
Install and configure MySQL database server for application data storage. While a VM-based database is recommended, this script provides container-based MySQL installation if needed. It opens a port accessible externally through the worker node's IP.

#### How to Run
```bash
sudo ./install_mysql8.sh
```

#### Input Example
```
Database Name: mydb
Database User: user01
Database Password: yourpassword
MySQL Service Name: mysql-svc
```

### 4️⃣ Tomcat10 Deployment

#### Purpose
Deploy and run web applications on Tomcat servers. The script builds a Docker image from the `deploy/tomcat10/Dockerfile`, pushes it to the master node's Docker Registry, and deploys containers (PODs) from this image. Multiple instances can be installed simultaneously, providing internal load balancing.

**Note:** The provided Dockerfile requires a `ROOT.war` file linked with Tomcat.

#### How to Run
```bash
sudo ./install_tomcat10.sh
```

#### Input Example
```
Service Name: blog-tomcat
Number of Instances: 2
```

### 5️⃣ Ingress & Certificate Configuration

#### Purpose
Connect internal services to external domains and configure SSL/TLS security.

**Important:** Ensure `certs/server.crt.pem` and `certs/server.key.pem` exist. These certificates are required when running `install_ingress-nginx.sh`.

#### How to Run
```bash
sudo ./install_ingress-nginx.sh
```

#### Input Example
```
Internal Service URL: http://blog-tomcat.production.svc.cluster.local:8080
Domain: blog.example.com
```

### 🗑️ Deletion Instructions

You can remove your k3s cluster setup using the `uninstall_k3s_full_stack.sh` script provided:

```bash
sudo ./uninstall_k3s_full_stack.sh
```

Select:
```
1) Delete Master Node
2) Delete Worker Node
```

## ✨ Expected Outcomes
- Simple automated deployment using Git
- Easy cluster management via Rancher web UI
- Secure external access with TLS

## 🗂️ Reference Scripts
| Configuration | Script File |
|---------------|-------------|
| Master/Worker Node Installation | install_k3s_full_stack.sh |
| MySQL Installation | install_mysql8.sh |
| Tomcat10 Deployment | install_tomcat10.sh |
| Ingress & Certificate Setup | install_ingress-nginx.sh |
| Cluster Deletion | uninstall_k3s_full_stack.sh |

## 🚧 Future Extensions
- CI/CD integration using GitHub Actions or Jenkins
- GitOps deployment with Argo CD
- Monitoring setup using Prometheus and Grafana
- Automated certificate renewal management

---

## 📌 Credits
Developed by the Graduate School of Information Technology and Entrepreneurship, Dankook University, Korea 🇰🇷

---

This automation setup provides a practical and efficient way to quickly build and manage Kubernetes infrastructure.
