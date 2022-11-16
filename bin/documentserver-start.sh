#!/bin/bash

mkdir -p $SNAP_DATA/var/log/supervisor/
mkdir -p $SNAP_DATA/var/run/
touch $SNAP_DATA/var/log/supervisor/supervisord.log
touch $SNAP_DATA/var/run/supervisord.pid

mkdir -p $SNAP_DATA/var/log/onlyoffice/documentserver/docservice/
mkdir -p $SNAP_DATA/var/log/onlyoffice/documentserver/converter/
mkdir -p $SNAP_DATA/var/log/onlyoffice/documentserver/gc/
mkdir -p $SNAP_DATA/var/log/onlyoffice/documentserver/metrics/
mkdir -p $SNAP_DATA/var/log/onlyoffice/documentserver-example/
mkdir -p $SNAP_DATA/var/lib/onlyoffice/documentserver-example/files/

touch $SNAP_DATA/var/log/onlyoffice/documentserver/docservice/out.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver/docservice/err.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver/converter/out.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver/converter/err.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver/gc/out.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver/gc/err.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver/metrics/out.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver/metrics/err.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver-example/out.log
touch $SNAP_DATA/var/log/onlyoffice/documentserver-example/err.log

EXAMPLE_ENABLED=$(snapctl get onlyoffice.example-enabled)
if [ "${EXAMPLE_ENABLED}" == "true" ]; then
    sed -i -e 's/autostart=false/autostart=true/'  $SNAP_DATA/etc/supervisor/conf.d/ds-example.conf
else
    sed -i -e 's/autostart=true/autostart=false/'  $SNAP_DATA/etc/supervisor/conf.d/ds-example.conf
fi

USE_UNAUTHORIZED_STORAGE_ENABLED=$(snapctl get onlyoffice.use-unautorized-storage)
if [ "${USE_UNAUTHORIZED_STORAGE_ENABLED}" == "true" ]; then
    sed -i -e 's/"rejectUnauthorized": true/"rejectUnauthorized": false/' /var/snap/oo-ds-test/current/etc/onlyoffice/documentserver/local.json
else
    sed -i -e 's/"rejectUnauthorized": false/"rejectUnauthorized": true/' /var/snap/oo-ds-test/current/etc/onlyoffice/documentserver/local.json
fi

LOOPBACK_ENABLED=$(snapctl get onlyoffice.loopback)
NGINX_CONF_PATH="$SNAP_DATA/etc/onlyoffice/documentserver/nginx"
if [ "${LOOPBACK_ENABLED}" == "true" ]; then
    sed -i -r 's/ #(allow)/ \1/' \
        $NGINX_CONF_PATH/ds.conf.tmpl $NGINX_CONF_PATH/ds-ssl.conf.tmpl
    sed -i -r 's/ #(deny)/ \1/' \
        $NGINX_CONF_PATH/ds.conf.tmpl $NGINX_CONF_PATH/ds-ssl.conf.tmpl
else
    sed -i -r 's/ (allow)/ #\1/' \
        $NGINX_CONF_PATH/ds.conf.tmpl $NGINX_CONF_PATH/ds-ssl.conf.tmpl
    sed -i -r 's/ (deny)/ #\1/' \
        $NGINX_CONF_PATH/ds.conf.tmpl $NGINX_CONF_PATH/ds-ssl.conf.tmpl
fi

export LC_ALL=C.UTF-8

#check fonts
FONTS_HASH_FILE=$SNAP_DATA/fonts-hash.md5
FONTS_HASH_NEW=$(find /usr/share/fonts | md5sum | cut -f 1 -d ' ')
FONTS_HASH_OLD=$(cat $FONTS_HASH_FILE)
if [ "${FONTS_HASH_NEW}" != "${FONTS_HASH_OLD}" ]; then
    echo "${FONTS_HASH_NEW}" > $FONTS_HASH_FILE
    $SNAP/usr/sbin/generate-all-fonts.sh
fi

JWT_SECRET=$(snapctl get onlyoffice.jwt-secret)
if [ "${JWT_SECRET}" == "default-jwt-secret" ]; then
    RANDOM_STRING=$(od -An -N4 -i < /dev/urandom | md5sum | head -c 10)
    snapctl set onlyoffice.jwt-secret=$RANDOM_STRING
fi

$SNAP/usr/bin/python $SNAP/usr/bin/supervisord -n -c $SNAP_DATA/etc/supervisor/supervisord.conf
