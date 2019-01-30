FROM alpine:3.8

ENV UID=1000 GID=1000 \
    GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
    NGINX_VERSION=1.14.2 \
    LUA_MODULE_VERSION=0.10.9rc8  \
    NGINX_DEVEL_KIT_VERSION=0.3.0 \
    NGINX_CACHE_PURGE_VERSION=2.3 \
    GEOIP_VERSION=1.6.11 \
    HEADERS_MORE_VERSION=0.32 \
    NGINX_CONF_DIR=/etc/nginx \
    NGINX_LOG_DIR=/var/log/nginx \
    NGINX_TEMP_DIR=/var/cache/nginx \
    NGINX_SETUP_DIR=/usr/src/nginx

LABEL description="nginx built from source" \
      nginx="nginx ${NGINX_VERSION}" \
      maintainer="JohnWu <v.la@live.cn>"

ARG WITH_NDK=true
ARG WITH_LUA=true
ARG WITH_PURGE=true
ARG WITH_UPSTREAM_CHECK=true

#china mirrors repos
RUN echo "https://mirrors.ustc.edu.cn/alpine/latest-stable/main" > /etc/apk/repositories \
&&  echo "https://mirrors.ustc.edu.cn/alpine/latest-stable/community" >> /etc/apk/repositories

RUN mkdir -p \
    ${NGINX_SETUP_DIR} \
    ${NGINX_LOG_DIR} \
    ${NGINX_CONF_DIR}/{conf.d,sites-enabled,certs} \
    ${NGINX_TEMP_DIR}/{body,fastcgi,proxy,scgi,uwsgi} \
    /var/www/nginx \
&& cd ${NGINX_SETUP_DIR} \
&& NB_CORES=$(getconf _NPROCESSORS_ONLN) \
&& NGINX_MODULES="" \
&& BUILD_DEPS=" \
    build-base linux-headers ca-certificates \
    patch openssl-dev cmake autoconf automake \
    curl pcre-dev zlib-dev luajit-dev libtool \
    gnupg libxslt-dev gd-dev perl-dev git geoip-dev git" \ 
&& apk -U upgrade && apk add --no-cache --virtual .build-deps ${BUILD_DEPS} \
&& \
# ngx_devel_kit module
    if [[ ${WITH_NDK} ]];then \
        NGINX_MODULES="${NGINX_MODULES} --add-module=${NGINX_SETUP_DIR}/ngx_devel_kit-${NGINX_DEVEL_KIT_VERSION}"; \
        curl -fSL https://github.com/simpl/ngx_devel_kit/archive/v${NGINX_DEVEL_KIT_VERSION}.tar.gz -o "${NGINX_SETUP_DIR}/ngx_devel_kit.tar"; \
        tar -zxC  "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/ngx_devel_kit.tar"; \
    fi \
&& \
# ngx_cache_purge module
    if [[ ${WITH_PURGE} ]];then \
        NGINX_MODULES="${NGINX_MODULES} --add-module=${NGINX_SETUP_DIR}/ngx_cache_purge-${NGINX_CACHE_PURGE_VERSION}"; \
        curl -fSL https://github.com/FRiCKLE/ngx_cache_purge/archive/${NGINX_CACHE_PURGE_VERSION}.tar.gz -o "${NGINX_SETUP_DIR}/ngx_cache_purge.tar"; \
        tar -zxC  "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/ngx_cache_purge.tar"; \
    fi \
&& \
# ngx_upstream_check module
    if [[ ${WITH_UPSTREAM_CHECK} ]];then \
        NGINX_MODULES="${NGINX_MODULES} --add-module=${NGINX_SETUP_DIR}/nginx_upstream_check_module-master"; \
        curl -fSL https://github.com/yaoweibin/nginx_upstream_check_module/archive/master.tar.gz -o "${NGINX_SETUP_DIR}/ngx_upstream_check.tar"; \
        tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/ngx_upstream_check.tar"; \
    fi \
&& \
# lua module
    if [[ ${WITH_UPSTREAM_CHECK} ]];then \
        NGINX_MODULES="${NGINX_MODULES} --add-module=${NGINX_SETUP_DIR}/lua-nginx-module-${LUA_MODULE_VERSION}"; \
        curl -fSL https://github.com/openresty/lua-nginx-module/archive/v${LUA_MODULE_VERSION}.tar.gz -o "lua_module.tar"; \
        tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/lua_module.tar"; \
        export LUAJIT_LIB=/usr/lib; \
        export LUAJIT_INC=/usr/include/luajit-2.1; \
    fi \

# headers-more module
&& NGINX_MODULES="${NGINX_MODULES} --add-module=${NGINX_SETUP_DIR}/headers-more-nginx-module-${HEADERS_MORE_VERSION}" \
&& curl -fSL https://github.com/openresty/headers-more-nginx-module/archive/v${HEADERS_MORE_VERSION}.tar.gz -o "${NGINX_SETUP_DIR}/headers-more-nginx-module-${HEADERS_MORE_VERSION}.tar.gz" \
&& tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/headers-more-nginx-module-${HEADERS_MORE_VERSION}.tar.gz" \

# ngx_brotli module
&& NGINX_MODULES="${NGINX_MODULES} --add-module=${NGINX_SETUP_DIR}/ngx_brotli" \
&& git clone https://github.com/bagder/libbrotli --depth=1 ${NGINX_SETUP_DIR}/libbrotli \
&& cd "${NGINX_SETUP_DIR}/libbrotli" \
&& ./autogen.sh && ./configure && make -j $NB_CORES && make install \
&& git clone --depth=1 https://github.com/google/ngx_brotli  "${NGINX_SETUP_DIR}/ngx_brotli" \
&& cd "${NGINX_SETUP_DIR}/ngx_brotli" \
&& git submodule update --init \

# geoip module
&& curl -fSL https://github.com/maxmind/geoip-api-c/releases/download/v${GEOIP_VERSION}/GeoIP-${GEOIP_VERSION}.tar.gz -o "${NGINX_SETUP_DIR}/geoip_module.tar" \
&& tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/geoip_module.tar" \
&& cd ${NGINX_SETUP_DIR}/GeoIP-${GEOIP_VERSION} \
&& ./configure && make -j $NB_CORES && make check && make install \

#prepare nginx source
&& curl -fSL http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o "${NGINX_SETUP_DIR}/nginx.tar" \
&& tar -zxC "${NGINX_SETUP_DIR}" -f "${NGINX_SETUP_DIR}/nginx.tar" \
&& cd ${NGINX_SETUP_DIR}/nginx-${NGINX_VERSION} \
&& curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc -o "${NGINX_SETUP_DIR}/nginx.tar.gz.asc" \
&& export GNUPGHOME="$(mktemp -d)" \
&& found=''; \
for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $GPG_KEYS from $server"; \
		gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
	done; \
   test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
   gpg --batch --verify "${NGINX_SETUP_DIR}/nginx.tar.gz.asc" "${NGINX_SETUP_DIR}/nginx.tar" \

#nginx_upstream_check_module patch
&& if [[ ${WITH_UPSTREAM_CHECK} ]];then \
   patch -p0 < ${NGINX_SETUP_DIR}/nginx_upstream_check_module-master/check_1.11.5+.patch; \
fi \

# Configure Nginx
&& echo "Configure ${NGINX_MODULES}" \
&& ./configure \
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
  --with-pcre \
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
  --with-http_degradation_module \
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
  ${NGINX_MODULES} \
&& make -j $NB_CORES && make install \

# install runDeps
&& ln -sf /usr/lib/nginx/modules /etc/nginx/modules \
&& strip /usr/sbin/nginx* \
&& strip /usr/lib/nginx/modules/*.so \
&& apk add --no-cache --virtual .gettext gettext \
&& mv /usr/bin/envsubst /tmp/ \
&& RUN_DEPENDENCIES="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
)" \
&& RUN_DEPENDENCIES="$RUN_DEPENDENCIES su-exec" \
&& echo "install rundeps $RUN_DEPENDENCIES" \
&& apk add --no-cache --virtual .nginx-rundeps tzdata $RUN_DEPENDENCIES \

# cleanup
&& apk del .build-deps \
&& apk del .gettext \
&& mv /tmp/envsubst /usr/local/bin/ \
&& cd $NGINX_CONF_DIR \
&& rm -rf ${NGINX_SETUP_DIR}/

COPY rootfs /
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 8000/tcp 4430/tcp

VOLUME ["${NGINX_CONF_DIR}","${NGINX_CONF_DIR}/conf.d","${NGINX_CONF_DIR}/certs","${NGINX_LOG_DIR}","/var/www"]

ENTRYPOINT ["/sbin/entrypoint.sh"]