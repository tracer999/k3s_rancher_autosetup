🌐 Language: [한국어](./README.md) | [English](./README_en.md) | [日本語](./README_ja.md) | [Español](./README_es.md)

# ⚙️ Scripts de Automatización para Clúster Kubernetes Ligero Basado en k3s

## 📌 Descripción General

Este repositorio proporciona un conjunto de **scripts de shell automatizados** para implementar un clúster Kubernetes ligero utilizando **k3s**, junto con componentes esenciales como MySQL, Tomcat, Ingress y NFS.

- Configuración por defecto: 1 nodo maestro y 1 nodo trabajador
- Los nodos trabajadores se pueden ampliar según sea necesario
- Configuración automática de Tomcat y almacenamiento compartido (NFS) para aplicaciones web
- Soporte para HTTPS con certificados personalizados a través de Ingress

---

## 📂 Flujo de Instalación

### 1️⃣ `install_k3s_full_stack.sh` — Instalar Nodo Maestro / Trabajador

- Script común para nodos maestro y trabajador
- En el nodo maestro instala Rancher, Ingress Controller, Docker Registry y cert-manager
- El nodo trabajador se une al clúster utilizando la IP y el token del maestro

```bash
sudo ./install_k3s_full_stack.sh
```

---

### 2️⃣ `install_mysql8.sh` — Instalar MySQL 8

- Implementa MySQL mediante Helm en el espacio de nombres `production`
- Si existe un volcado SQL inicial en `deploy/mysql/init-sql/database_dump.sql`, se aplicará automáticamente

```bash
sudo ./install_mysql8.sh
```

---

### 3️⃣ `setup_nfs_and_pv.sh` — Configurar Servidor NFS y Crear PV/PVC

- Instala el servidor NFS en el nodo maestro y configura el directorio compartido
- Crea PersistentVolume y PersistentVolumeClaim para Kubernetes automáticamente

```bash
sudo ./setup_nfs_and_pv.sh
```

> Los archivos YAML generados se guardan en `pv_pvc_yaml/`.

---

### 4️⃣ `install_tomcat10.sh` — Implementar Contenedor Tomcat10

- Despliega un Pod Tomcat10 montado con PVC compartido
- Utiliza el Dockerfile en `deploy/tomcat10/` y requiere un archivo `ROOT.war`
- La imagen Docker se construye y se carga al registro local

```bash
sudo ./install_tomcat10.sh
```

> Tomcat estará disponible en el puerto NodePort `31808`.

---

### 5️⃣ `install_ingress-nginx.sh` — Configurar Ingress y SSL

- Requiere archivos de certificado `certs/server.crt.pem` y `server.key.pem` preconfigurados
- Crea automáticamente un recurso Ingress con soporte TLS para el dominio especificado

```bash
sudo ./install_ingress-nginx.sh
```

---

## ❌ Eliminación del Clúster

### `uninstall_k3s_full_stack.sh`

- Elimina todos los componentes: Rancher, cert-manager, Ingress, Docker Registry
- Soporta eliminación tanto en nodos maestro como trabajadores, con menú de selección
- Limpia los espacios de nombres, finalizadores, configuraciones de registro y servicios

```bash
sudo ./uninstall_k3s_full_stack.sh
```

---

## 🗂️ Resumen de Scripts

| Función                  | Nombre del Script             |
|--------------------------|-------------------------------|
| Instalar k3s + Rancher   | install_k3s_full_stack.sh     |
| Instalar MySQL 8         | install_mysql8.sh             |
| Configurar NFS + PV/PVC  | setup_nfs_and_pv.sh           |
| Implementar Tomcat10     | install_tomcat10.sh           |
| Configurar Ingress + SSL | install_ingress-nginx.sh      |
| Eliminar clúster         | uninstall_k3s_full_stack.sh   |

---

## 📁 Estructura de Directorios

- `deploy/mysql/init-sql/`: Archivo SQL de inicialización
- `deploy/tomcat10/`: Dockerfile de Tomcat y archivo ROOT.war
- `certs/`: Certificados SSL (`server.crt.pem`, `server.key.pem`)
- `pv_pvc_yaml/`: Archivos YAML para PV y PVC

---

## 👨‍💻 Desarrollo y Uso

- Desarrollado como parte de un proyecto de laboratorio en la Escuela de Posgrado en Tecnología de la Información y Emprendimiento de la Universidad de Dankook (Corea)
- Dirigido a ingenieros e investigadores que deseen construir clústeres ligeros con k3s

---

Este conjunto de scripts permite implementar rápidamente un clúster Kubernetes funcional basado en k3s, ideal para pruebas, desarrollo o despliegues ligeros.
