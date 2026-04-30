#!/bin/bash

set -e

apt-get update -qq
apt-get install -y -qq curl unzip

NC_VERSION="${NEXTCLOUD_VERSION}"

if [ -z "$NC_VERSION" ] || [ "$NC_VERSION" = "latest" ]; then
    NC_URL="https://download.nextcloud.com/server/releases/latest.zip"
    echo "[*] Téléchargement de Nextcloud (dernière version stable)..."
else
    NC_URL="https://download.nextcloud.com/server/releases/nextcloud-${NC_VERSION}.zip"
    echo "[*] Téléchargement de Nextcloud v${NC_VERSION}..."
fi

curl -L --progress-bar "$NC_URL" -o /mnt/server/nextcloud.zip

if [ ! -s /mnt/server/nextcloud.zip ]; then
    echo "[!] Échec du téléchargement."
    exit 1
fi

echo "[*] Extraction..."
unzip -q /mnt/server/nextcloud.zip -d /mnt/server/
rm /mnt/server/nextcloud.zip
mkdir -p /mnt/server/nextcloud/data

echo "STATUS=downloaded" > /mnt/server/.data

echo ""
echo "[✓] Nextcloud installé. Démarrez le serveur pour finaliser la configuration."
