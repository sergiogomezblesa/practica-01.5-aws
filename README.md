# practica-01.5-aws

# Práctica: Certificado SSL/TLS en Apache (HTTPS)

Documento técnico que describe la creación y configuración de un certificado SSL/TLS en un servidor web Apache sobre Ubuntu, usando una pila LAMP. 

## 1. Estructura del proyecto

```
.
├── README.md
├── conf
│   ├── 000-default.conf
│   └── virtualhost.conf.template
└── scripts
    ├── .env
    ├── install_lamp.sh
    └── setup_letsencrypt_certificate.sh
```

## 2. Requisitos previos

- Máquina con Ubuntu Server .
- Puertos **80** y **443** abiertos en el firewall / grupo de seguridad.
- Dominio apuntando a la IP pública del servidor.
- Usuario con privilegios `sudo`.

## 3. Instalación de la pila LAMP

Desde la carpeta `scripts`:

```bash
cd scripts
chmod +x install_lamp.sh
sudo ./install_lamp.sh
```

El script realiza estos pasos:

1. Actualiza los repositorios (`apt update`).
2. Instala Apache (`apache2`).
3. Copia `000-default.conf` a `/etc/apache2/sites-available/`.
4. Habilita el módulo `rewrite`.
5. Instala PHP, `libapache2-mod-php` y `php-mysql`.
6. Reinicia Apache.
7. Copia `index.php` a `/var/www/html` y asigna el propietario `www-data`.
8. Instala MySQL Server.

## 4. Certificado autofirmado con OpenSSL

Un certificado autofirmado cifra la comunicación, pero ninguna autoridad de certificación lo avala, por lo que el navegador mostrará una advertencia.

### 4.1. Generar la clave privada y el certificado

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/apache-selfsigned.key \
  -out /etc/ssl/certs/apache-selfsigned.crt \
  -subj "/C=ES/ST=Andalucia/L=Almeria/O=IES Celia/OU=Practicas/CN=practica-aur.ddns.net"
```

| Parámetro          | Significado                                                            |
| ------------------ | ---------------------------------------------------------------------- |
| `-x509`            | Genera un certificado autofirmado en lugar de una solicitud (CSR).     |
| `-nodes`           | No cifra la clave privada con contraseña (Apache arranca sin pedirla). |
| `-days 365`        | Validez de un año.                                                     |
| `-newkey rsa:2048` | Crea una clave RSA de 2048 bits.                                       |
| `-subj`            | Datos del titular; `CN` debe coincidir con el dominio.                 |

### 4.2. Configurar el VirtualHost HTTPS

Edita `/etc/apache2/sites-available/default-ssl.conf` con:

```apache
<VirtualHost *:443>
  ServerName practica-aur.ddns.net
  DocumentRoot /var/www/html/
  DirectoryIndex index.php index.html

  SSLEngine on
  SSLCertificateFile    /etc/ssl/certs/apache-selfsigned.crt
  SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```

### 4.3. Habilitar SSL y recargar Apache

```bash
sudo a2enmod ssl
sudo a2ensite default-ssl.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

### 4.4. Redirigir HTTP a HTTPS

En el VirtualHost del puerto 80 añade:

```apache
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
```

## 5. Certificado de Let's Encrypt con Certbot

### 5.1. Variables de entorno (`scripts/.env`)

```bash
LETS_ENCRYPT_DOMAIN="practica-aur.ddns.net"
LETS_ENCRYPT_EMAIL=admin@iescelia.org
```

### 5.2. Plantilla del VirtualHost

`conf/virtualhost.conf.template` contiene el VirtualHost del puerto 80 con las variables `${LETS_ENCRYPT_DOMAIN}` y `${LETS_ENCRYPT_EMAIL}`. Para que Certbot localice el sitio, la directiva `ServerName` debe estar **descomentada**:

```apache
<VirtualHost *:80>
  ServerName ${LETS_ENCRYPT_DOMAIN}
  ServerAdmin ${LETS_ENCRYPT_EMAIL}
  DocumentRoot /var/www/html/
  DirectoryIndex index.php index.html
  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```

### 5.3. Ejecución del script

```bash
cd scripts
chmod +x setup_letsencrypt_certificate.sh
sudo ./setup_letsencrypt_certificate.sh
```

Pasos que realiza el script:

1. Carga las variables de `.env` (`set -a; source .env`).
2. Instala y actualiza `snapd` / `core`.
3. Elimina la versión de Certbot instalada con `apt`.
4. Instala Certbot con `snap install --classic certbot` y crea el enlace simbólico `/usr/bin/certbot`.
5. Deshabilita los VirtualHost `000-default.conf` y `default-ssl.conf`.
6. Genera `/etc/apache2/sites-available/<dominio>.conf` con `envsubst` a partir de la plantilla.
7. Habilita el nuevo sitio y recarga Apache.
8. Solicita el certificado con `certbot --apache`.

### 5.4. Renovación automática

Certbot instalado por snap crea un temporizador de renovación. Compruébalo con:

```bash
sudo systemctl list-timers | grep certbot
sudo certbot renew --dry-run
```

## 6. Comprobación del funcionamiento

1. Accede a `https://practica-aur.ddns.net` desde el navegador.
2. Con certificado autofirmado, el navegador mostrará una advertencia; acéptala para continuar. Con Let's Encrypt aparecerá el candado sin avisos.
3. Consulta los detalles del certificado (emisor, validez, dominio).
4. Verifica desde la terminal:

```bash
openssl s_client -connect practica-aur.ddns.net:443 -servername practica-aur.ddns.net </dev/null | openssl x509 -noout -issuer -subject -dates
```

## 7. Conclusiones

Se ha configurado HTTPS en Apache de dos formas: con un certificado autofirmado, útil para entornos de prueba pero no verificable por terceros, y con un certificado de Let's Encrypt, gratuito, de confianza pública y con renovación automática, desplegado mediante scripts reproducibles.
