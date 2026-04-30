# DockerNextcloud

Image Docker Alpine + PHP 8.2 + Nginx conçue pour héberger [Nextcloud](https://nextcloud.com) via le panel [Pterodactyl](https://pterodactyl.io).

## Stack

- Alpine Linux (latest)
- PHP 8.3 avec les extensions requises par Nextcloud
- Nginx
- Bash

## Utilisation

### Docker Hub / GHCR

```
ghcr.io/oxiwanv2/dockernextcloud:latest
```

### Pterodactyl

Ajoute l'image dans le champ **Docker Images** de ton egg :

```
ghcr.io/oxiwanv2/dockernextcloud:latest
```

L'`entrypoint.sh` lit la variable `STARTUP` injectée par Pterodactyl et exécute la commande correspondante.

## Build local

```bash
docker build -t dockernextcloud .
```

## Extensions PHP incluses

`gd` `curl` `xml` `zip` `mbstring` `session` `pdo` `pdo_sqlite` `pdo_mysql` `pdo_pgsql` `intl` `bcmath` `ctype` `dom` `fileinfo` `iconv` `openssl` `exif` `bz2` `opcache`
