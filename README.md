[![Build Status](https://travis-ci.org/vla/docker-nginx.svg?branch=master)](https://travis-ci.org/vla/docker-nginx)

# Supported tags and respective `Dockerfile` links

- [`latest` , `1.10.1`  (1.10.1/Dockerfile)](https://github.com/vla/docker-nginx/blob/master/Dockerfile)

# Introduction

Nginx-1.10.1 镜像集成模块列表：
- pagespeed
- luaJIT
- lua-nginx-module
- nginx_upstream_check_module
- nginx_cache_purge_module
- nginx_devel_kit

Dockerfile文件的`ARG`参数可控制`开启/关闭`相应功能

```
ARG WITH_DEBUG=false
ARG WITH_NDK=false
ARG WITH_LUA=true
ARG WITH_PURGE=true
ARG WITH_HTTP_IMAGE_FILTER=false
ARG WITH_HTTP_XSLT=false
ARG WITH_PAGESPEED=true
ARG WITH_UPSTREAM_CHECK=true
```

# Getting started

## Installation

自动化构建镜像的可用[Dockerhub](https://hub.docker.com/r/johnwu/nginx)和推荐的安装方法

```bash
docker pull johnwu/nginx:1.10.1
```

或者你可以自己构建镜像

```bash
docker build -t johnwu/nginx github.com/johnwu/docker-nginx
```

## Quickstart

运行nginx：

```bash
docker run --name nginx -d \
  -p 80:80 --restart=always \
  johnwu/nginx-loup 
```

或者您可以使用示例[docker-compose.yml](docker-compose.yml)文件启动容器

## Configuration

自定义您的配置文件覆盖容器默认的`/etc/nginx/nginx.conf`配置

```bash
docker run --name nginx -d \
-v /some/nginx.conf:/etc/nginx/nginx.conf:ro \
johnwu/nginx
```

挂载您自己的`sites-enabled`目录到`/etx/nginx/sites-enabled`

```bash
docker run --name nginx  -d \
-v /some/nginx.conf:/etc/nginx/nginx.conf:ro \
-v /srv/docker/nginx/sites-enabled:/etc/nginx/sites-enabled \
johnwu/nginx
```

重新加载的NGINX配置使用`kill -s HUP`发送到容器上

```bash
docker kill -s HUP nginx
```

## Logs

访问Nginx日志位于`/var/log/nginx`
```bash
docker exec -it nginx tail -f /var/log/nginx/access.log
```

# Test

## 执行以下命令启动容器

```bash
docker run -p 80:80 --name nginx -d \
johnwu/nginx \
nginx -c /etc/nginx/test.conf 
```

## 地址测试


先访问`http://localhost/index.html` ，然后再次访问`http://localhost/purge/index.html`会看到效果  
其实访问`http://localhost/index.html`地址已经使用反向代理到`http://localhost:8045/index.html`页面上


访问`http://localhost/lua`页面将会显示`hello lua.`

访问`http://localhost/status1`页面将会显示stub状态

访问`http://localhost/status2`页面将会显示upstream状态


