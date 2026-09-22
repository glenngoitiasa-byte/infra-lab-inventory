#!/usr/bin/env bash

set -euo pipefail

echo "Virtual Machine getting stopped..."
pkill -f "hostfwd=tcp::2222-:22" || true

echo "Cleaning instance and temporal archives"
rm -rf vm_instance/
rm -f /tmp/inventory-api.tar.gz

echo "The enviroment has been destroyed succesfully"
