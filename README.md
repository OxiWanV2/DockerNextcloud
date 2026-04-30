# Nextcloud Docker Image

Image Docker légère basée sur Alpine Linux, intégrant PHP 8.3 et Nginx, conçue pour déployer et héberger Nextcloud facilement via le panel Pterodactyl.

## Version disponible

- `ghcr.io/oxiwanv2/dockernextcloud:latest` - PHP 8.3 + Nginx sur Alpine 3.20

## Variables d'environnement

### Configuration serveur (requises)

| Variable | Défaut | Description |
|----------|--------|-------------|
| `SERVER_PORT` | — | Port d'écoute Nginx |
| `SERVER_IP` | `localhost` | Adresse IP ou domaine principal |

### Configuration Nextcloud ( VARIABLE PTERODACTYL )

| Variable | Défaut | Description |
|----------|--------|-------------|
| `TRUSTED_DOMAIN` | — | Domaines supplémentairs de confiance ex: domaine de la node, séparés par des virgules |
| `NEXTCLOUD_VERSION`| latest | Permet de spécifier une version de Nextcloud à installer |

## Utilisation

### Via Pterodactyl

Ajoute l'image dans le champ **Docker Images** de l'egg :

```
ghcr.io/oxiwanv2/dockernextcloud:latest
```

L'`entrypoint.sh` lit la variable `STARTUP` injectée par Pterodactyl et démarre automatiquement PHP-FPM et Nginx.

**Premier démarrage :** Le script d'installation à configurer est `install.sh`. Il suffit de le renseigner dans l'egg Pterodactyl, ensuite un assistant interactif demandera le nom et le mot de passe admin.

### Docker Run basique

```bash
docker run -d \
  --name nextcloud \
  -p 8080:8080 \
  -e SERVER_PORT=8080 \
  -e SERVER_IP=localhost \
  -v ./nextcloud:/home/container \
  ghcr.io/oxiwanv2/dockernextcloud:latest
```

### Docker Compose

```yaml
services:
  nextcloud:
    image: ghcr.io/oxiwanv2/dockernextcloud:latest
    container_name: nextcloud
    ports:
      - "8080:8080"
    environment:
      SERVER_PORT: "8080"
      SERVER_IP: "cloud.example.com"
      TRUSTED_DOMAIN: "cloud.example.com"
    volumes:
      - ./nextcloud:/home/container
    restart: unless-stopped
```

## Build local

```bash
docker build -t dockernextcloud .
```

## Extensions PHP incluses

`gd` `curl` `xml` `xmlwriter` `xmlreader` `simplexml` `zip` `mbstring` `session` `pdo` `pdo_sqlite` `pdo_mysql` `pdo_pgsql` `intl` `bcmath` `ctype` `dom` `fileinfo` `iconv` `openssl` `exif` `bz2` `posix` `pcntl` `apcu` `gmp` `sodium` `sysvsem` `opcache` `pecl-imagick`
