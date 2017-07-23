FROM alpine:3.5

ENV UID=1000 GID=1000 \ 
    GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8

ENV NGINX_VERSION=1.12.1 \
    LUA_MODULE_VERSION=0.10.9rc8  \
    NGINX_DEVEL_KIT_VERSION=0.3.0 \
    NGINX_CACHE_PURGE_VERSION=2.3 \
    GEOIP_VERSION=1.6.11 \
    HEADERS_MORE_VERSION=0.32 \
    NGINX_SITECONF_DIR=/etc/nginx/sites-enabled \
    NGINX_LOG_DIR=/var/log/nginx \
    NGINX_TEMP_DIR=/var/cache/nginx \
    NGINX_SETUP_DIR=/usr/src/nginx

ARG WITH_DEBUG=false
ARG WITH_NDK=true
ARG WITH_LUA=true
ARG WITH_PURGE=true
ARG WITH_UPSTREAM_CHECK=true

COPY setup/ ${NGINX_SETUP_DIR}/
RUN sh ${NGINX_SETUP_DIR}/install.sh

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8000/tcp 4430/tcp

VOLUME ["${NGINX_SITECONF_DIR}","/etc/nginx/conf.d","etc/nginx/certs","/var/log/nginx","/var/www"]

LABEL description="nginx built from source" \
      nginx="nginx ${NGINX_VERSION}" \
      maintainer="JohnWu <v.la@live.cn>"

ENTRYPOINT ["/sbin/entrypoint.sh"]