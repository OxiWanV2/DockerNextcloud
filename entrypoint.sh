#!/bin/bash

NC_DIR="/home/container/nextcloud"
DATA_DIR="/home/container/nextcloud/data"

if [ ! -f "$NC_DIR/index.php" ]; then
    echo "[*] Première installation de Nextcloud..."

    NC_VERSION=$(curl -s https://api.github.com/repos/nextcloud/server/releases/latest \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 | sed 's/v//')

    echo "[*] Téléchargement de Nextcloud v${NC_VERSION}..."
    wget -q "https://download.nextcloud.com/server/releases/nextcloud-${NC_VERSION}.zip" \
        -O /tmp/nextcloud.zip

    unzip -q /tmp/nextcloud.zip -d /home/container/
    rm /tmp/nextcloud.zip
    mkdir -p "$DATA_DIR"
fi

if [ ! -f "$NC_DIR/config/config.php" ]; then
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║     Configuration de Nextcloud       ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    read -p "  Nom d'utilisateur admin : " ADMIN_USER
    read -s -p "  Mot de passe admin      : " ADMIN_PASS
    echo ""

    echo "[*] Installation en cours..."
    php "$NC_DIR/occ" maintenance:install \
        --database sqlite \
        --database-name nextcloud \
        --admin-user "$ADMIN_USER" \
        --admin-pass "$ADMIN_PASS" \
        --data-dir "$DATA_DIR" 2>/dev/null

    php "$NC_DIR/occ" config:system:set trusted_domains 0 --value="${SERVER_IP:-localhost}"
    php "$NC_DIR/occ" config:system:set trusted_domains 1 --value="localhost"
    php "$NC_DIR/occ" config:system:set default_language --value="fr"
    php "$NC_DIR/occ" config:system:set default_locale --value="fr_BE"
    php "$NC_DIR/occ" config:system:set overwriteprotocol --value="http"

    echo "[✓] Nextcloud configuré avec succès !"
fi

mkdir -p /tmp/nginx/client_body /tmp/nginx/proxy /tmp/nginx/fastcgi /tmp/nginx/uwsgi /tmp/nginx/scgi

cat > /tmp/php-fpm.conf << EOF
[global]
pid = /tmp/php-fpm.pid
error_log = /tmp/php-fpm.log

[www]
listen = /tmp/php-fpm.sock
listen.mode = 0666
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOF

cat > /tmp/nginx.conf << EOF
worker_processes 1;
pid /tmp/nginx.pid;

events { worker_connections 1024; }

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /tmp/nginx_access.log;
    error_log /tmp/nginx_error.log;
    client_body_temp_path /tmp/nginx/client_body;
    proxy_temp_path /tmp/nginx/proxy;
    fastcgi_temp_path /tmp/nginx/fastcgi;
    uwsgi_temp_path /tmp/nginx/uwsgi;
    scgi_temp_path /tmp/nginx/scgi;

    server {
        listen ${SERVER_PORT};
        root $NC_DIR;
        index index.php index.html;
        client_max_body_size 10G;

        location = /robots.txt { allow all; log_not_found off; access_log off; }
        location / { rewrite ^ /index.php; }

        location ~ \.php(?:\$|/) {
            fastcgi_split_path_info ^(.+\.php)(/.*)\$;
            include /etc/nginx/fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
            fastcgi_param HTTPS off;
            fastcgi_param front_controller_active true;
            fastcgi_pass unix:/tmp/php-fpm.sock;
            fastcgi_intercept_errors on;
            fastcgi_request_buffering off;
        }

        location ~ \.(?:css|js|woff2?|svg|gif|png|ico)\$ {
            try_files \$uri /index.php\$request_uri;
            expires 6M;
            access_log off;
        }
    }
}
EOF

php-fpm82 -y /tmp/php-fpm.conf
echo "[✓] Nextcloud démarré sur le port ${SERVER_PORT}"
exec nginx -e /tmp/nginx_error.log -c /tmp/nginx.conf -g "daemon off;"
