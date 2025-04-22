
# k3s Rancher Automation Setup Guide

## 🚀 Overview

Recently, software development and deployment environments are shifting from traditional Monolithic Architecture to Microservice Architecture (MSA). Consequently, operational environments are also transitioning from virtual machines (VMs) to container-based solutions, increasing the demand for container orchestration tools.

This guide aims to simplify the learning curve associated with Kubernetes by using k3s, a lightweight Kubernetes distribution. It automates the setup of Rancher and other essential components required for creating and managing Kubernetes clusters.

## 📌 Introduction to k3s

k3s is a lightweight Kubernetes distribution offering the following key features:
- Quick and easy installation with minimal resource usage
- Single binary for simplicity and reduced complexity
- Built-in Helm, Traefik, and Containerd

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
Enter domain for Rancher: rancher.ydata.co.kr
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
Install and configure MySQL database server for application data storage.

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
Deploy and run web applications on Tomcat servers.

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

#### How to Run
```bash
sudo ./install_ingress-nginx.sh
```

#### Input Example
```
Internal Service URL: http://blog-tomcat.production.svc.cluster.local:8080
Domain: blog.example.com
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

## 🚧 Future Extensions
- CI/CD integration using GitHub Actions or Jenkins
- GitOps deployment with Argo CD
- Monitoring setup using Prometheus and Grafana
- Automated certificate renewal management

This automation setup provides a practical and efficient way to quickly build and manage Kubernetes infrastructure.
