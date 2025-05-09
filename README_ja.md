🌐 Language: [한국어](./README.md) | [English](./README_en.md) | [日本語](./README_ja.md) | [Español](./README_es.md)

# ⚙️ k3sベースの軽量Kubernetesクラスター自動構成スクリプト集

## 📌 概要

このリポジトリは、**軽量Kubernetesディストリビューションであるk3s**を用いて、マスター-ワーカ構造のクラスターを簡単に構築し、MySQL、Tomcat、Ingress、NFSなどのサービスを自動でインストール・運用するための**シェルスクリプト集**です。

- デフォルト構成：マスターノード1台、ワーカーノード1台
- 必要に応じてワーカーノードを追加可能
- Webアプリケーションに必要なTomcatおよび共有ストレージ（NFS）を自動構成
- 独自証明書を利用したHTTPS Ingressに対応

---

## 📂 インストール手順の概要

### 1️⃣ `install_k3s_full_stack.sh` — マスター/ワーカーノードのセットアップ

- マスター・ワーカー共通のスクリプトです。
- マスターノードではRancher、Ingress Controller、Docker Registry、cert-managerを自動インストールします。
- ワーカーノードはマスターのIPアドレスとトークンでクラスターに参加します。

```bash
sudo ./install_k3s_full_stack.sh
```

---

### 2️⃣ `install_mysql8.sh` — MySQL 8のインストール

- Helmチャートを使用して `production` ネームスペースにMySQLをデプロイします。
- `deploy/mysql/init-sql/database_dump.sql` に初期SQLがあれば自動適用されます。

```bash
sudo ./install_mysql8.sh
```

---

### 3️⃣ `setup_nfs_and_pv.sh` — NFSサーバーのセットアップとPV/PVCの作成

- マスターノードにNFSサーバーをインストールし、共有フォルダを設定します。
- Kubernetesで使用可能なPersistentVolumeおよびPersistentVolumeClaimを生成します。

```bash
sudo ./setup_nfs_and_pv.sh
```

> YAMLファイルは `pv_pvc_yaml/` ディレクトリに保存されます。

---

### 4️⃣ `install_tomcat10.sh` — Tomcat10コンテナのデプロイ

- 共有PVCをマウントしたTomcat10 Podをデプロイします。
- `deploy/tomcat10/` にあるDockerfileを使用し、`ROOT.war`が必要です。
- Dockerイメージをビルドしてローカルレジストリにプッシュします。

```bash
sudo ./install_tomcat10.sh
```

> NodePort `31808` で外部アクセス可能です。

---

### 5️⃣ `install_ingress-nginx.sh` — Ingressと証明書の設定

- `certs/server.crt.pem` と `server.key.pem` を事前に準備しておく必要があります。
- ドメインを指定すると、自動的にIngressリソースを作成し、TLSを有効化します。

```bash
sudo ./install_ingress-nginx.sh
```

---

## ❌ クラスタの削除

### `uninstall_k3s_full_stack.sh`

- Rancher、cert-manager、Ingress、Docker Registryなどの構成をすべて削除します。
- マスター・ワーカーノード両方で実行可能で、選択メニューが表示されます。

```bash
sudo ./uninstall_k3s_full_stack.sh
```

---

## 🗂️ スクリプトファイル一覧

| 機能 | スクリプト名 |
|------|--------------------------|
| k3s + Rancherのインストール | install_k3s_full_stack.sh |
| MySQL 8のインストール | install_mysql8.sh |
| NFSとPV/PVCの設定 | setup_nfs_and_pv.sh |
| Tomcat10のデプロイ | install_tomcat10.sh |
| Ingressと証明書の設定 | install_ingress-nginx.sh |
| クラスタの削除 | uninstall_k3s_full_stack.sh |

---

## 📁 その他ディレクトリ構成

- `deploy/mysql/init-sql/`: 初期SQLファイルの保存場所
- `deploy/tomcat10/`: Tomcat用DockerfileとROOT.war配置
- `certs/`: HTTPS証明書 (`server.crt.pem`, `server.key.pem`)
- `pv_pvc_yaml/`: PVおよびPVCのYAMLファイル保存フォルダ

---

## 👨‍💻 開発・貢献

- 作成元：韓国・檀国大学 情報融合技術・起業大学院
- 対象：k3sベースで軽量なKubernetesクラスターを構築したい技術者・研究者向け

---

本プロジェクトは、開発・実験環境において軽量なKubernetes環境を素早く構築・運用するための実用的なツールセットです。
