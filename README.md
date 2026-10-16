# Production Data Platform: Automated Cloud Data Infrastructure

A production-grade, highly available **Data Platform** built on **Azure Kubernetes Service (AKS)** and orchestrated via **Terraform** and **CloudNativePG (CNPG)**. This project demonstrates enterprise-level infrastructure-as-code (IaC), GitOps-ready database management, automated Point-in-Time Recovery (PITR) backups to Azure Blob Storage, and zero-trust Layer 4 security isolation.

---

## 🏗️ Architecture Overview

The infrastructure enforces strict segregation between the cloud provisioning layer and the cloud native application layer:

*   **Infrastructure Layer (Terraform):** Deploys a cost-efficient Azure Kubernetes Service (AKS) Free Tier cluster inside a dedicated Virtual Network (VNet) spanning across West Europe availability zones. It provisions an isolated, immutable Azure Storage Account dedicated to database lifecycle artifacts.
*   **Database Orchestration Layer (CloudNativePG):** Deploys a 3-node PostgreSQL cluster running in a High-Availability topology (1 Primary, 2 Hot-Standbys) with automated failover handling.
*   **Security & Data Lifecycle Layer:** Implements strict inbound network isolation policies ensuring database traffic is restricted exclusively to the operator control plane and active peer nodes. It pipes continuous, Gzip-compressed Write-Ahead Logs (WAL) over TLS directly to Azure Blob Storage for sub-minute Point-in-Time Recovery capability.

---
<img width="794" height="284" alt="image" src="https://github.com/user-attachments/assets/e89ec74a-1a4a-4ae5-8469-fb14df2eb1a2" />

## 📂 Repository Structure

```text
├── terraform/
│   ├── main.tf           # Provisions AKS (Free Tier) & Virtual Network (VNet)
│   └── storage.tf        # Provisions Azure Storage Account & Blob Container for PITR
├── kubernetes/
│   ├── cluster.yaml      # Main PostgreSQL cluster mapped to Azure Blob Storage
│   └── network-policy.yaml# Strict Layer 4 Ingress Network Isolation Rules
└── README.md             # Project documentation
```

---

## ⚙️ Core Technical Specifications

### 1. Cloud Infrastructure (Terraform)
*   **Network:** Custom VNet (`10.0.0.0/16`) with a dedicated AKS node pool subnet (`10.0.1.0/24`).
*   **Compute:** 3-node `Standard_D2as_v5` node pool providing zone redundancy and stable compute performance.
*   **Storage Account:** Secure blob engine with structural configurations tuned to prevent cross-tenant exposure and maintain storage keys dynamically.

### 2. High Availability Database (`cluster.yaml`)
*   **Topology:** 3 independent active engine instances managed via the CloudNativePG operator control plane.
*   **Persistent Storage:** Dynamic mounting via the native Azure Disk (`default`) `StorageClass` using 10Gi volumes per node.
*   **Backup Strategy:** Automated base snapshots along with streaming `wal` archiving targeting remote blob storage endpoints securely mapped through internal cluster secrets.

### 3. Layer 4 Zero-Trust Security (`network-policy.yaml`)
*   **Ingress Lock:** Implements strict default-deny boundaries for raw data layers.
*   **Authorized Paths:** Explicitly opens port `5432` and port `8000` solely to internal cluster communication loops and the database management control plane.

---

## 🚀 Deployment Guide

### Prerequisites
*   Terraform v1.5+
*   Azure CLI
*   kubectl

### Phase 1: Infrastructure Provisioning
```bash
cd terraform/
terraform init
terraform apply -auto-approve
```

### Phase 2: Cluster Credential Synchronization
Extract the protected storage credentials and seed them into the dedicated database namespace:

#### For Linux / macOS (Bash/Zsh):
```bash
# 1. Ensure the target database namespace exists
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

# 2. Extract raw primary connection key
KEY=\$(terraform output -raw cnpg_storage_primary_key)

# 3. Inject credentials as a native secret object into AKS
kubectl create secret generic cnpg-azure-backup-secret \
  --namespace=database \
  --from-literal=AZURE_STORAGE_ACCOUNT="cnpgbackup16165b2a" \
  --from-literal=AZURE_STORAGE_KEY="\$KEY"
```

#### For Windows (PowerShell):
```powershell
# 1. Ensure the target database namespace exists
kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -

# 2. Extract raw primary connection key
\$KEY = terraform output -raw cnpg_storage_primary_key

# 3. Inject credentials as a native secret object into AKS
kubectl create secret generic cnpg-azure-backup-secret `
  --namespace=database `
  --from-literal=AZURE_STORAGE_ACCOUNT="cnpgbackup16165b2a" `
  --from-literal=AZURE_STORAGE_KEY="\$KEY"
```

### Phase 3: CloudNativePG Operator Installation
Deploy the native Kubernetes cloud-data controller instance using the official release distribution:
```bash
kubectl apply --server-side -f https://githubusercontent.com
```

### Phase 4: Database & Security Rollout
Apply the database engine schema along with layer-4 isolation policies:
```bash
cd ../kubernetes/
kubectl apply -f network-policy.yaml -n database
kubectl apply -f cluster.yaml -n database
```

---

## 🔍 Verification & Telemetry

Monitor database bootstrapping sequences and high-availability health checks:
```bash
# Watch active pods initializing sequentially inside the namespace
kubectl get pods -n database -w

# Check database operator synchronization metrics
kubectl get cluster production-postgres -n database -o yaml
```

