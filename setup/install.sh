#!/bin/bash
set -e

NGINX_DOWNLOAD_URL="http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
NGX_PAGESPEED_DOWNLOAD_URL="https://github.com/pagespeed/ngx_pagespeed/archive/v${NPS_VERSION}-beta.tar.gz"
PSOL_DOWNLOAD_URL="https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz"
NGINX_DEVEL_KIT_URL="https://github.com/simpl/ngx_devel_kit/archive/v${NGINX_DEVEL_KIT_VERSION}.tar.gz"
LUA_JIT_URL="http://luajit.org/download/LuaJIT-${LUAJIT_VERSION}.tar.gz"
LUA_URL="https://github.com/openresty/lua-nginx-module/archive/v${LUA_MODULE_VERSION}.tar.gz"
NGINX_CACHE_PURGE_URL="https://github.com/FRiCKLE/ngx_cache_purge/archive/${NGINX_CACHE_PURGE_VERSION}.tar.gz"
NGINX_UPSTREAM_CHECK_URL="https://github.com/yaoweibin/nginx_upstream_check_module/archive/master.tar.gz"

RUNTIME_DEPENDENCIES="libssl1.0.0 libpcre++0 libgeoip1"
BUILD_DEPENDENCIES="ca-certificates make gcc g++ patch libssl-dev libpcre++-dev libgeoip-dev"

download_and_extract() {
  local src=${1}
  local dest=${2}
  local tarball=$(basename ${src})

  if [ ! -f ${NGINX_SETUP_DIR}/src/${tarball} ]; then
    echo "Downloading ${tarball}..."
    mkdir -p ${NGINX_SETUP_DIR}/src/
    wget -cq ${src} -O ${NGINX_SETUP_DIR}/src/${tarball}
  fi

  echo "Extracting ${tarball}..."
  mkdir -p ${dest}
  tar -zxf ${NGINX_SETUP_DIR}/src/${tarball} --strip=1 -C ${dest}
  rm -rf ${NGINX_SETUP_DIR}/src/${tarball}
}

${WITH_DEBUG} && {
  EXTRA_ARGS="${EXTRA_ARGS} --with-debug"
}

# prepare http image filter module support
${WITH_HTTP_IMAGE_FILTER} && {
  RUNTIME_DEPENDENCIES="$RUNTIME_DEPENDENCIES libgd3"
  BUILD_DEPENDENCIES="$BUILD_DEPENDENCIES libgd2-xpm-dev"
  EXTRA_ARGS="${EXTRA_ARGS} --with-http_image_filter_module"
}

# prepare http xslt module support
${WITH_HTTP_XSLT} && {
  RUNTIME_DEPENDENCIES="$RUNTIME_DEPENDENCIES libxslt1.1"
  BUILD_DEPENDENCIES="$BUILD_DEPENDENCIES libxslt-dev"
  EXTRA_ARGS="${EXTRA_ARGS} --with-http_xslt_module"
}

#runtime dependencies and build dependencies
apt-get update
apt-get install --no-install-recommends --no-install-suggests -y ${RUNTIME_DEPENDENCIES} ${BUILD_DEPENDENCIES}

# prepare ngx_devel_kit support
${WITH_NDK} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/nginx_devel_kit"
  download_and_extract "${NGINX_DEVEL_KIT_URL}" "${NGINX_SETUP_DIR}/nginx_devel_kit"
}

# prepare ngx_cache_purge module support
${WITH_PURGE} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/ngx_cache_purge"
  download_and_extract "${NGINX_CACHE_PURGE_URL}" "${NGINX_SETUP_DIR}/ngx_cache_purge"
}

# prepare ngx_upstream_check module support
${WITH_UPSTREAM_CHECK} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/ngx_upstream_check"
  download_and_extract "${NGINX_UPSTREAM_CHECK_URL}" "${NGINX_SETUP_DIR}/ngx_upstream_check"
}

# prepare pagespeed module support
${WITH_PAGESPEED} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/ngx_pagespeed"
  download_and_extract "${NGX_PAGESPEED_DOWNLOAD_URL}" "${NGINX_SETUP_DIR}/ngx_pagespeed"
  download_and_extract "${PSOL_DOWNLOAD_URL}" "${NGINX_SETUP_DIR}/ngx_pagespeed/psol"
}

${WITH_LUA} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/lua_module"
  download_and_extract "${LUA_URL}" "${NGINX_SETUP_DIR}/lua_module"
  download_and_extract "${LUA_JIT_URL}" "${NGINX_SETUP_DIR}/lua_jit"
  cd ${NGINX_SETUP_DIR}/lua_jit
  make -j$(nproc) && make install
  export LUAJIT_LIB=/usr/local/lib
  export LUAJIT_INC=/usr/local/include/luajit-2.0
  ldconfig
}

#nginx user role
addgroup --system ${NGINX_USER}
adduser --system --disabled-password \
  --disabled-login --home /var/www/nginx \
  -uid 1000 --shell /sbin/nologin \
  ${NGINX_USER}
usermod -aG nginx nginx
mkdir -p /var/www/nginx && chown nginx:nginx -R /var/www/nginx

#build nginx
download_and_extract "${NGINX_DOWNLOAD_URL}" "${NGINX_SETUP_DIR}/nginx"
cd ${NGINX_SETUP_DIR}/nginx

if [[ ${WITH_UPSTREAM_CHECK} ]];then
   patch -p0 < ${NGINX_SETUP_DIR}/ngx_upstream_check/check_1.9.2+.patch
fi

./configure \
  --prefix=/var/www/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --sbin-path=/usr/sbin \
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
  ${EXTRA_ARGS}

make -j$(nproc) && make install

mkdir -p ${NGINX_TEMP_DIR}/{body,fastcgi,proxy,scgi,uwsgi}
mkdir -p ${NGINX_SITECONF_DIR}
mkdir -p /etc/nginx/conf.d/

cp ${NGINX_SETUP_DIR}/test.conf /etc/nginx/

cat > ${NGINX_SITECONF_DIR}/default <<EOF
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

# cleanup
apt-get purge -y --auto-remove ${BUILD_DEPENDENCIES}
rm -rf ${NGINX_SETUP_DIR}/
rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector
ln -sf /dev/stdout /var/log/nginx/access.log 
ln -sf /dev/stderr /var/log/nginx/error.log