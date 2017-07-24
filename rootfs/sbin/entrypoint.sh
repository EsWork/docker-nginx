#!/bin/sh
set -e

chmod -R 0755 ${NGINX_LOG_DIR} 
chmod -R 0755 ${NGINX_CONF_DIR}/sites-enabled
chown -R $UID:$GID $NGINX_CONF_DIR $NGINX_LOG_DIR $NGINX_TEMP_DIR /etc/nginx /var/www

#允许参数传递到nginx
if [[ "${1:0:1}" = '-' ]]; then
  #e.g: -g "daemon off;"
  EXTRA_ARGS="$@"
  set --
elif [[ "${1}" == nginx || "${1}" == $(which nginx) ]]; then
  #e.g: nginx -g "daemon off;"
  EXTRA_ARGS="${@:5}" #fix busybox
  #EXTRA_ARGS="${@:2}"
  set --
fi

if [[ -z "${1}" ]]; then
  echo "Starting nginx..."
  #exec su-exec $UID:$GID /sbin/tini -- nginx
  exec su-exec $UID:$GID $(which nginx) -g "daemon off;" ${EXTRA_ARGS}
else
  exec "$@"
fi
