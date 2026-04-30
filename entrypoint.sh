#!/bin/bash

NC_DIR="/home/container/nextcloud"
DATA_FILE="/home/container/.data"
LOG_NGINX="/home/container/nginx.log"
LOG_FPM="/home/container/php-fpm.log"
PHP="php -d memory_limit=512M"

STATUS=""
[ -f "$DATA_FILE" ] && STATUS=$(grep "^STATUS=" "$DATA_FILE" | cut -d'=' -f2)

if [ "$STATUS" = "" ]; then
    echo "[!] Fichier .data introuvable. Relancez l'installation depuis le panel."
    exit 1
fi

if [ "$STATUS" = "downloaded" ]; then
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║     Configuration de Nextcloud       ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
    echo "  Nom d'utilisateur admin :"
    read -r ADMIN_USER
    echo "  Mot de passe admin :"
    stty -echo
    read -r ADMIN_PASS
    stty echo
    echo ""

    echo "[*] Installation en cours..."
    $PHP "$NC_DIR/occ" maintenance:install \
        --database sqlite \
        --database-name nextcloud \
        --admin-user "$ADMIN_USER" \
        --admin-pass "$ADMIN_PASS" \
        --data-dir "$NC_DIR/data"

    if [ $? -ne 0 ]; then
        echo "[!] Échec de l'installation."
        exit 1
    fi

    sed -i 's/STATUS=downloaded/STATUS=configured/' "$DATA_FILE"
    echo "[✓] Nextcloud installé."
fi

echo "[*] Application de la configuration..."

# Trusted domains de base : IP + localhost
$PHP "$NC_DIR/occ" config:system:set trusted_domains 0 --value="${SERVER_IP:-localhost}"
$PHP "$NC_DIR/occ" config:system:set trusted_domains 1 --value="${SERVER_IP:-localhost}:${SERVER_PORT}"
$PHP "$NC_DIR/occ" config:system:set trusted_domains 2 --value="localhost"
$PHP "$NC_DIR/occ" config:system:set trusted_domains 3 --value="localhost:${SERVER_PORT}"

# Trusted domains supplémentaires : variable TRUSTED_DOMAIN séparée par virgules
if [ -n "${TRUSTED_DOMAIN}" ]; then
    IFS=',' read -ra EXTRA_DOMAINS <<< "${TRUSTED_DOMAIN}"
    IDX=4
    for DOMAIN in "${EXTRA_DOMAINS[@]}"; do
        DOMAIN=$(echo "$DOMAIN" | tr -d ' ')
        [ -z "$DOMAIN" ] && continue
        $PHP "$NC_DIR/occ" config:system:set trusted_domains $IDX --value="$DOMAIN"
        IDX=$((IDX + 1))
    done
fi

$PHP "$NC_DIR/occ" config:system:set default_language --value="fr"
$PHP "$NC_DIR/occ" config:system:set default_locale --value="fr_BE"
$PHP "$NC_DIR/occ" config:system:set overwriteprotocol --value="http"
$PHP "$NC_DIR/occ" config:system:set log_type --value="file"
$PHP "$NC_DIR/occ" config:system:set logfile --value="/home/container/nextcloud.log"

if php -r 'exit(extension_loaded("apcu") ? 0 : 1);'; then
    $PHP "$NC_DIR/occ" config:system:set memcache.local --value="\\OC\\Memcache\\APCu"
fi

echo "[✓] Configuration appliquée."

mkdir -p /tmp/nginx/client_body /tmp/nginx/proxy /tmp/nginx/fastcgi /tmp/nginx/uwsgi /tmp/nginx/scgi

cat > /tmp/php-fpm.conf << EOF
[global]
pid = /tmp/php-fpm.pid
error_log = ${LOG_FPM}

[www]
listen = /tmp/php-fpm.sock
listen.mode = 0666
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
php_admin_value[memory_limit] = 512M
php_admin_flag[apc.enabled] = 1
EOF

# Config nginx baseée sur la recommandation officielle Nextcloud :
# https://docs.nextcloud.com/server/latest/admin_manual/installation/nginx.html
#
# Points d'entrée PHP réels : index.php, remote.php, public.php,
#   cron.php, status.php, ocs/v1.php, ocs/v2.php, ocs-provider/index.php
# Tout le reste est re-écrit vers index.php (front controller).
# Les assets statiques (.mjs, .js, .css, images...) sont servis
# directement par nginx sans passer par PHP.
cat > /tmp/nginx.conf << EOF
worker_processes 1;
pid /tmp/nginx.pid;

events { worker_connections 1024; }

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log ${LOG_NGINX};
    error_log ${LOG_NGINX};
    client_body_temp_path /tmp/nginx/client_body;
    proxy_temp_path /tmp/nginx/proxy;
    fastcgi_temp_path /tmp/nginx/fastcgi;
    uwsgi_temp_path /tmp/nginx/uwsgi;
    scgi_temp_path /tmp/nginx/scgi;

    # MIME type pour les modules ES
    types {
        application/javascript mjs;
    }

    server {
        listen ${SERVER_PORT};
        root ${NC_DIR};
        client_max_body_size 10G;

        location = /robots.txt  { allow all; log_not_found off; access_log off; }
        location = /favicon.ico { try_files \$uri =204; log_not_found off; access_log off; }

        # --- Fichiers statiques servis DIRECTEMENT par nginx (sans PHP) ---
        # Inclut .mjs (modules ES), .js, .css, fonts, images, etc.
        location ~* \.(?:css|js|mjs|map|woff2?|ttf|otf|eot|svg|gif|png|jpg|jpeg|ico|webp|avif)\$ {
            try_files \$uri =404;
            expires 6M;
            add_header Cache-Control "public, immutable";
            access_log off;
        }

        # --- Points d'entrée PHP légitimes de Nextcloud ---
        # (index, remote, public, cron, status, ocs/v1, ocs/v2, ocs-provider)
        location ~ ^/(?:index|remote|public|cron|status|updater/.+|ocs/v[12]|ocs-provider/.+)\.php(?:\$|/) {
            fastcgi_split_path_info ^(.+?\.php)(/.*)\$;
            set \$path_info \$fastcgi_path_info;
            include /etc/nginx/fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO       \$path_info;
            fastcgi_param HTTPS           off;
            fastcgi_param front_controller_active true;
            fastcgi_pass  unix:/tmp/php-fpm.sock;
            fastcgi_intercept_errors on;
            fastcgi_request_buffering off;
            fastcgi_read_timeout 600;
        }

        # --- Bloquer tout autre .php (sécurité) ---
        location ~ \.php\$ { return 404; }

        # --- Front controller : tout le reste via index.php ---
        # rewrite sans boucle : /login -> /index.php (capturé par la règle .php ci-dessus)
        location / {
            rewrite ^ /index.php last;
        }
    }
}
EOF

php-fpm82 -y /tmp/php-fpm.conf
if [ $? -ne 0 ]; then
    echo "[!] Echec demarrage php-fpm."
    exit 1
fi

nginx -t -e ${LOG_NGINX} -c /tmp/nginx.conf
if [ $? -ne 0 ]; then
    echo "[!] Configuration nginx invalide."
    cat ${LOG_NGINX}
    exit 1
fi

echo "[✓] Nextcloud démarré sur le port ${SERVER_PORT}"
echo "[✓] Logs : ${LOG_NGINX} | ${LOG_FPM} | /home/container/nextcloud.log"
exec nginx -e ${LOG_NGINX} -c /tmp/nginx.conf -g "daemon off;"
