FROM alpine:3.5
LABEL maintainer "v.la@live.cn"

ENV NGINX_VERSION=1.10.3 \
    LUA_MODULE_VERSION=0.10.6 \
    NGINX_DEVEL_KIT_VERSION=0.3.0 \
    NGINX_CACHE_PURGE_VERSION=2.3 \
    NGINX_USER=nginx \
    NGINX_SITECONF_DIR=/etc/nginx/sites-enabled \
    NGINX_LOG_DIR=/var/log/nginx \
    NGINX_TEMP_DIR=/var/lib/nginx \
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

EXPOSE 80/tcp 443/tcp

VOLUME ["${NGINX_SITECONF_DIR}"]
ENTRYPOINT ["/sbin/entrypoint.sh"]