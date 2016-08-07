#!/bin/bash
set -e

create_log_dir() {
  mkdir -p ${NGINX_LOG_DIR}
  chmod -R 0755 ${NGINX_LOG_DIR}
  chown -R ${NGINX_USER}:root ${NGINX_LOG_DIR}
}

create_tmp_dir(){
  mkdir -p ${NGINX_TEMP_DIR}
  chown -R ${NGINX_USER}:root ${NGINX_TEMP_DIR}
}

create_siteconf_dir() {
  mkdir -p ${NGINX_SITECONF_DIR}
  chmod -R 755 ${NGINX_SITECONF_DIR}
}

create_log_dir
create_tmp_dir
create_siteconf_dir

#允许参数传递到nginx
if [[ ${1:0:1} = '-' ]]; then
  #e.g: -g "daemon off;"
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == nginx || ${1} == $(which nginx) ]]; then
  #e.g: nginx -g "daemon off;"
  EXTRA_ARGS="${@:2}"
  set --
fi
echo ${1}
if [[ -z ${1} ]]; then
  echo "Starting nginx..."
  exec $(which nginx) -c /etc/nginx/nginx.conf -g "daemon off;" ${EXTRA_ARGS}
else
  exec "$@"
fi
