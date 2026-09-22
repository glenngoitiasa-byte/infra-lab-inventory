> 📌 **Note:** This repository automates the infrastructure and deployment pipeline for the [inventory-api](https://github.com/glenngoitiasa-byte/inventory-api) project.

# 🚀 Automated End-to-End Infrastructure & API Deployment Pipeline

An automated Infrastructure as Code (IaC) and deployment pipeline for a cloud-based **Debian 12 Virtual Machine** running a containerized **FastAPI + PostgreSQL** backend stack. Built with **QEMU/KVM**, **Cloud-Init**, **Ansible**, **Docker Compose**, and **uv**.

---

## 🏛️ Architecture Overview

The pipeline executes a zero-touch workflow: it provisions an ephemeral virtual machine, configures core networking and credentials on early boot, provisions system dependencies via Ansible, and deploys the containerized application.

```mermaid
graph TD
    subgraph Host["Host Machine (Linux)"]
        A[deploy.sh] -->|1. Creates Ephemeral Copy-On-Write Disk| B(QEMU Hypervisor)
        A -->|2. Generates NoCloud ISO| B
        A -->|4. Runs Playbook| F[Ansible Engine]
    end

    subgraph VM["Debian 12 GenericCloud VM"]
        B -->|3. Boots Image + Cloud-Init| C[Systemd-Networkd & SSH]
        F -->|5. Installs Docker & Tools| D[Docker Engine]
        F -->|6. Copies API Source Code| E[/opt/inventory-api/]
        
        subgraph DockerStack["Docker Compose Stack"]
            D -->|7. Launches Containers| G[FastAPI Container - Port 8000]
            D -->|7. Launches Containers| H[(PostgreSQL 15 Container)]
            G <-->|Internal Network| H
        end
    end

    A <-->|SSH Tunnel - Port 2222| C
    Host <-->|HTTP Port 8000 Forwarding| G
