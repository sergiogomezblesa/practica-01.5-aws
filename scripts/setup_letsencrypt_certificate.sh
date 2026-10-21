#!/bin/bash
set -ex

set -a
source .env

#Realizamos la instalación y actualización de snapd
sudo snap install core
sudo snap refresh core

#Eliminamos si existe la versión anterior de Certbot
sudo apt remove certbot -y

#Instalamos el cliente de Certbot
sudo snap install --classic certbot

#Creamos un alias para el comando certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

#Deshabilitamos los virtual hosts por defecto de Apache
a2dissite 000-default.conf
a2dissite default-ssl.conf

envsubst '$LETS_ENCRYPT_DOMAIN ${LETS_ENCRYPT_EMAIL}' < ../conf/virtualhost.conf.template > /etc/apache2/sites-available/${LETS_ENCRYPT_DOMAIN}.conf

#Habilitamos el nuevo virtual host de Apache
sudo a2ensite ${LETS_ENCRYPT_DOMAIN}.conf

#Recargamos la configuración de Apache para aplicar los cambios
sudo systemctl reload apache2

#Ejecutamos el comando para obtener el certificado SSL de Let's Encrypt
sudo certbot --apache -m d- $LETS_ENCRYPT_EMAIL --agree-tos --noeff-email -d $LETS_ENCRYPT_DOMAIN --non-interactive