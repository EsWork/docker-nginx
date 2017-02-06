#!/bin/bash
set -e

NGINX_DOWNLOAD_URL="http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
NGX_PAGESPEED_DOWNLOAD_URL="https://github.com/pagespeed/ngx_pagespeed/archive/v${NPS_VERSION}-beta.tar.gz"
PSOL_DOWNLOAD_URL="https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz"
NGINX_DEVEL_KIT_URL="https://github.com/simpl/ngx_devel_kit/archive/v${NGINX_DEVEL_KIT_VERSION}.tar.gz"
LUA_URL="https://github.com/openresty/lua-nginx-module/archive/v${LUA_MODULE_VERSION}.tar.gz"
NGINX_CACHE_PURGE_URL="https://github.com/FRiCKLE/ngx_cache_purge/archive/${NGINX_CACHE_PURGE_VERSION}.tar.gz"
NGINX_UPSTREAM_CHECK_URL="https://github.com/yaoweibin/nginx_upstream_check_module/archive/master.tar.gz"

RUN_DEPENDENCIES
BUILD_DEPENDENCIES="gcc g++  patch libc-dev make openssl-dev \
pcre-dev zlib-dev linux-headers luajit-dev\
curl gnupg libxslt-dev gd-dev perl-dev geoip-dev"

${WITH_DEBUG} && {
  EXTRA_ARGS="${EXTRA_ARGS} --with-debug"
}


mkdir -p ${NGINX_SETUP_DIR}
cd ${NGINX_SETUP_DIR}

#build dependencies
apk add --no-cache --virtual .build-deps ${BUILD_DEPENDENCIES}

# prepare ngx_devel_kit support
${WITH_NDK} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/ngx_devel_kit-${NGINX_DEVEL_KIT_VERSION}"
  curl -fSL  "${NGINX_DEVEL_KIT_URL}" -o "${NGINX_SETUP_DIR}/ngx_devel_kit.tar"
  tar -zxC  "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/ngx_devel_kit.tar" 
}

# prepare ngx_cache_purge module support
${WITH_PURGE} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/ngx_cache_purge-${NGINX_CACHE_PURGE_VERSION}"
  curl -fSL  "${NGINX_CACHE_PURGE_URL}" -o "${NGINX_SETUP_DIR}/ngx_cache_purge.tar"
  tar -zxC  "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/ngx_cache_purge.tar" 
}

# prepare ngx_upstream_check module support
${WITH_UPSTREAM_CHECK} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/nginx_upstream_check_module-master"
  curl -fSL "${NGINX_UPSTREAM_CHECK_URL}" -o "${NGINX_SETUP_DIR}/ngx_upstream_check.tar"
  tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/ngx_upstream_check.tar"
}

# prepare pagespeed module support
${WITH_PAGESPEED} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/ngx_pagespeed-${NPS_VERSION}-beta"
  curl -fSL "${NGX_PAGESPEED_DOWNLOAD_URL}" -o "${NGINX_SETUP_DIR}/ngx_pagespeed.tar"
  tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/ngx_pagespeed.tar"

  curl -fSL "${PSOL_DOWNLOAD_URL}" -o "${NGINX_SETUP_DIR}/psol.tar"
  tar -zxC "${NGINX_SETUP_DIR}/ngx_pagespeed-${NPS_VERSION}-beta" -f "${NGINX_SETUP_DIR}/psol.tar"
}

${WITH_LUA} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/lua-nginx-module-${LUA_MODULE_VERSION}"

  curl -fSL "${LUA_URL}" -o "${NGINX_SETUP_DIR}/lua_module.tar"
  tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/lua_module.tar"

  cd ${NGINX_SETUP_DIR}/LuaJIT-${LUAJIT_VERSION}
  make -j$(getconf _NPROCESSORS_ONLN) && make install
  export LUAJIT_LIB=/usr/local/lib
  export LUAJIT_INC=/usr/local/include/luajit-2.0
}

#nginx user role
mkdir -p /var/www/nginx
addgroup -S ${NGINX_USER}
adduser -D -S -h /var/www/nginx \
  -u 1000 -s /sbin/nologin -G ${NGINX_USER} ${NGINX_USER}

#build nginx
curl -fSL "${NGINX_DOWNLOAD_URL}" -o "${NGINX_SETUP_DIR}/nginx.tar"
tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/nginx.tar"

cd ${NGINX_SETUP_DIR}/nginx-${NGINX_VERSION}

if [[ ${WITH_UPSTREAM_CHECK} ]];then
   patch -p0 < ${NGINX_SETUP_DIR}/nginx_upstream_check_module-master/check_1.9.2+.patch
fi

./configure \
  --prefix=/var/www/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --sbin-path=/usr/sbin \
  --modules-path=/usr/lib/nginx/modules \
  --http-log-path=/var/log/nginx/access.log \
  --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock \
  --pid-path=/run/nginx.pid \
  --user=${NGINX_USER} \
  --group=${NGINX_USER} \
  --http-client-body-temp-path=${NGINX_TEMP_DIR}/body \
  --http-fastcgi-temp-path=${NGINX_TEMP_DIR}/fastcgi \
  --http-proxy-temp-path=${NGINX_TEMP_DIR}/proxy \
  --http-scgi-temp-path=${NGINX_TEMP_DIR}/scgi \
  --http-uwsgi-temp-path=${NGINX_TEMP_DIR}/uwsgi \
  --with-pcre-jit \
  --with-ipv6 \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_realip_module \
  --with-http_auth_request_module \
  --with-http_secure_link_module \
  --with-http_random_index_module \
  --with-http_addition_module \
  --with-http_dav_module \
  --with-http_geoip_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_v2_module \
  --with-http_sub_module \
  --with-http_flv_module \
  --with-http_mp4_module \
  --with-stream \
  --with-stream_ssl_module \
  --with-mail \
  --with-mail_ssl_module \
  --with-threads \
  --with-file-aio \
  --with-http_xslt_module=dynamic \
  --with-http_image_filter_module=dynamic \
	--with-http_geoip_module=dynamic \
	--with-http_perl_module=dynamic \
  ${EXTRA_ARGS}

make -j$(getconf _NPROCESSORS_ONLN) && make install

mkdir -p ${NGINX_TEMP_DIR}/{body,fastcgi,proxy,scgi,uwsgi}
mkdir -p ${NGINX_SITECONF_DIR}
mkdir -p /etc/nginx/conf.d/

cp ${NGINX_SETUP_DIR}/test.conf /etc/nginx/

cat > ${NGINX_SITECONF_DIR}/default.conf <<EOF
server {
  listen 80 default_server;
  listen [::]:80 default_server ipv6only=on;
  server_name localhost;

  root /var/www/nginx/html;
  index index.html index.htm;

  location / {
    try_files \$uri \$uri/ =404;
  }

  error_page  500 502 503 504 /50x.html;
    location = /50x.html {
    root html;
  }
}

EOF


ln -sf /usr/lib/nginx/modules /etc/nginx/modules
strip /usr/sbin/nginx*
strip /usr/lib/nginx/modules/*.so

# cleanup
apk del .build-deps 
rm -rf ${NGINX_SETUP_DIR}/

# forward request and error logs to docker log collector
ln -sf /dev/stdout /var/log/nginx/access.log 
ln -sf /dev/stderr /var/log/nginx/error.log