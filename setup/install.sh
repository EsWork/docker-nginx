#!/bin/sh
set -e

# cat > /etc/apk/repositories <<EOF
# https://mirrors.ustc.edu.cn/alpine/latest-stable/main
# https://mirrors.ustc.edu.cn/alpine/latest-stable/community
# EOF
# apk update 

NGINX_DOWNLOAD_URL="http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
NGINX_DEVEL_KIT_URL="https://github.com/simpl/ngx_devel_kit/archive/v${NGINX_DEVEL_KIT_VERSION}.tar.gz"
LUA_URL="https://github.com/openresty/lua-nginx-module/archive/v${LUA_MODULE_VERSION}.tar.gz"
NGINX_CACHE_PURGE_URL="https://github.com/FRiCKLE/ngx_cache_purge/archive/${NGINX_CACHE_PURGE_VERSION}.tar.gz"
NGINX_UPSTREAM_CHECK_URL="https://github.com/yaoweibin/nginx_upstream_check_module/archive/master.tar.gz"
MAXMIND_URL="https://github.com/maxmind/geoip-api-c/releases/download/v${GEOIP_VERSION}/GeoIP-${GEOIP_VERSION}.tar.gz"
HEADERS_MORE_URL="https://github.com/openresty/headers-more-nginx-module/archive/v${HEADERS_MORE_VERSION}.tar.gz"

BUILD_DEPENDENCIES="build-base linux-headers ca-certificates \
patch openssl-dev cmake autoconf automake go \
curl pcre-dev zlib-dev luajit-dev libtool \
gnupg libxslt-dev gd-dev perl-dev git geoip-dev git"

${WITH_DEBUG} && {
  EXTRA_ARGS="${EXTRA_ARGS} --with-debug"
}

mkdir -p ${NGINX_SETUP_DIR}
cd ${NGINX_SETUP_DIR}

#build dependencies
echo "install build-deps $BUILD_DEPENDENCIES"
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

#lua module support
${WITH_LUA} && {
  EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/lua-nginx-module-${LUA_MODULE_VERSION}"

  curl -fSL "${LUA_URL}" -o "${NGINX_SETUP_DIR}/lua_module.tar"
  tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/lua_module.tar"

  export LUAJIT_LIB=/usr/lib
  export LUAJIT_INC=/usr/include/luajit-2.1
}

#headers-more module support
EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/headers-more-nginx-module-${HEADERS_MORE_VERSION}"
curl -fSL "${HEADERS_MORE_URL}" -o "${NGINX_SETUP_DIR}/headers-more-nginx-module-${HEADERS_MORE_VERSION}.tar.gz"
tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/headers-more-nginx-module-${HEADERS_MORE_VERSION}.tar.gz"

#ngx_brotli module support
EXTRA_ARGS="${EXTRA_ARGS} --add-module=${NGINX_SETUP_DIR}/ngx_brotli"
git clone https://github.com/bagder/libbrotli --depth=1 ${NGINX_SETUP_DIR}/libbrotli
cd "${NGINX_SETUP_DIR}/libbrotli"
./autogen.sh && ./configure && make -j $(getconf _NPROCESSORS_ONLN) && make install
git clone --depth=1 https://github.com/google/ngx_brotli  "${NGINX_SETUP_DIR}/ngx_brotli"
cd "${NGINX_SETUP_DIR}/ngx_brotli"
git submodule update --init

# install geoip
curl -fSL $MAXMIND_URL -o "${NGINX_SETUP_DIR}/geoip_module.tar"
tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/geoip_module.tar"
cd ${NGINX_SETUP_DIR}/GeoIP-${GEOIP_VERSION}
./configure && make -j $(getconf _NPROCESSORS_ONLN) && make check && make install 

#nginx default www
mkdir -p /var/www/nginx

#build nginx
curl -fSL "${NGINX_DOWNLOAD_URL}" -o "${NGINX_SETUP_DIR}/nginx.tar"
tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/nginx.tar"

cd ${NGINX_SETUP_DIR}/nginx-${NGINX_VERSION}

curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o "${NGINX_SETUP_DIR}/nginx.tar.gz.asc" 
export GNUPGHOME="$(mktemp -d)"
found='';
for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $GPG_KEYS from $server"; \
		gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
	done;

test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1;
gpg --batch --verify "${NGINX_SETUP_DIR}/nginx.tar.gz.asc"  "${NGINX_SETUP_DIR}/nginx.tar"
rm -r "$GNUPGHOME" "${NGINX_SETUP_DIR}/nginx.tar.gz.asc"


#nginx_upstream_check_module patch
if [[ ${WITH_UPSTREAM_CHECK} ]];then
   patch -p0 < ${NGINX_SETUP_DIR}/nginx_upstream_check_module-master/check_1.11.5+.patch
fi

./configure \
  --prefix=/var/www/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --sbin-path=/usr/sbin \
  --modules-path=/usr/lib/nginx/modules \
  --http-log-path=/var/log/nginx/access.log \
  --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock \
  --pid-path=/tmp/nginx.pid \
  --http-client-body-temp-path=${NGINX_TEMP_DIR}/body \
  --http-fastcgi-temp-path=${NGINX_TEMP_DIR}/fastcgi \
  --http-proxy-temp-path=${NGINX_TEMP_DIR}/proxy \
  --http-scgi-temp-path=${NGINX_TEMP_DIR}/scgi \
  --http-uwsgi-temp-path=${NGINX_TEMP_DIR}/uwsgi \
  --with-pcre-jit \
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
  --with-http_slice_module \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-stream_realip_module \
  --with-stream_geoip_module=dynamic \
  --with-mail \
  --with-mail_ssl_module \
  --with-threads \
  --with-file-aio \
  --with-compat \
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
  listen 8000 default_server;
  listen [::]:8000 default_server ipv6only=on;
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

apk add --no-cache --virtual .gettext gettext
mv /usr/bin/envsubst /tmp/

RUN_DEPENDENCIES="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
)"
RUN_DEPENDENCIES="$RUN_DEPENDENCIES su-exec"
echo "install rundeps $RUN_DEPENDENCIES"
apk add --no-cache --virtual .nginx-rundeps $RUN_DEPENDENCIES

# cleanup
apk del .build-deps
apk del .gettext
mv /tmp/envsubst /usr/local/bin/
cd /
rm -rf ${NGINX_SETUP_DIR}/
