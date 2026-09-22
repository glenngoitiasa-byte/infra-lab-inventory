#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_IMG="${SCRIPT_DIR}/base_images/debian-base.qcow2"

if [ ! -f "$BASE_IMG" ]; then
    echo "Downloading base Debian12 GenericCloud... "
    mkdir -p base_images
    wget -O "$BASE_IMG" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
fi

VM_DIR="${SCRIPT_DIR}/vm_instance"
WORK_IMG="${VM_DIR}/debian-target.qcow2"
SEED_ISO="${VM_DIR}/seed.iso"
SSH_PORT=2222

echo "[###            ] Limpiando instancias previas y creando disco efímero..."
pkill -f "hostfwd=tcp::${SSH_PORT}-:22" || true
mkdir -p "${VM_DIR}"
qemu-img create -f qcow2 -b "${BASE_IMG}" -F qcow2 "${WORK_IMG}" 10G

echo "[######         ] Generando archivos NoCloud para Cloud-Init..."
cat <<EOF >"${VM_DIR}/user-data"
#cloud-config
users:
  - name: sysadmin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILAgxwt4fvNo63296QwYc9g2foDdjJFhGTW+mCIgF3cM 

ssh_pwauth: true
chpasswd:
  list: |
    sysadmin:debian123
  expire: false

# bootcmd configura la red en la fase temprana antes de systemd-networkd-wait-online
bootcmd:
  - mkdir -p /etc/systemd/network
  - printf '[Match]\nName=e*\n\n[Network]\nDHCP=yes\n' > /etc/systemd/network/10-ethernet.network
  - systemctl enable --now systemd-networkd
EOF

cat <<'EOF' >"${VM_DIR}/meta-data"
instance-id: debian-vm-01
local-hostname: debian-lab
EOF

cloud-localds "$SEED_ISO" "${VM_DIR}/user-data" "${VM_DIR}/meta-data"

echo "[#########      ] Lanzando máquina virtual en QEMU (segundo plano)..."
qemu-system-x86_64 \
    -enable-kvm \
    -m 2048 \
    -smp 2 \
    -hda "${WORK_IMG}" \
    -cdrom "${SEED_ISO}" \
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22,hostfwd=tcp::8000-:8000,hostfwd=tcp::5432-:5432 \
    -device virtio-net-pci,netdev=net0 \
    -display none \
    -daemonize

echo "[############   ] Esperando a que el servicio SSH responda en la VM..."
MAX_RETRIES=30
RETRY_COUNT=0
until ssh-keyscan -p "${SSH_PORT}" 127.0.0.1 2>/dev/null | grep -q "ssh-"; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "${RETRY_COUNT}" -ge "${MAX_RETRIES}" ]; then
        echo "[ERROR] Tiempo de espera agotado. La máquina virtual no respondió por SSH."
        exit 1
    fi
    sleep 2
done

echo "[###############] Ejecutando Playbook de Ansible..."
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
    -i ansible/inventory.ini \
    --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
    ansible/site.yml

echo "¡Despliegue completado con éxito!"
