# inspired from https://hub.docker.com/r/danday74/nginx-lua/~/dockerfile/
FROM alpine:3.6 as build

RUN apk --no-cache upgrade
RUN apk --no-cache add gcc make openssl-dev pcre-dev zlib-dev linux-headers curl gnupg libxslt-dev gd-dev geoip-dev musl-dev

ENV VER_NGINX=1.13.5
RUN curl -LO http://nginx.org/download/nginx-${VER_NGINX}.tar.gz
RUN tar -xzf nginx-${VER_NGINX}.tar.gz && rm nginx-${VER_NGINX}.tar.gz

ENV VER_LUAJIT=2.0.5
RUN curl -LO http://luajit.org/download/LuaJIT-${VER_LUAJIT}.tar.gz
RUN tar -xzf LuaJIT-${VER_LUAJIT}.tar.gz && rm LuaJIT-${VER_LUAJIT}.tar.gz

ENV VER_NGINX_DEVEL_KIT=0.3.0
ENV NGINX_DEVEL_KIT ngx_devel_kit-${VER_NGINX_DEVEL_KIT}
RUN curl -L https://github.com/simpl/ngx_devel_kit/archive/v${VER_NGINX_DEVEL_KIT}.tar.gz -o ${NGINX_DEVEL_KIT}.tar.gz
RUN tar -xzf ${NGINX_DEVEL_KIT}.tar.gz && rm ${NGINX_DEVEL_KIT}.tar.gz

ENV VER_LUA_NGINX_MODULE=0.10.10
ENV LUA_NGINX_MODULE lua-nginx-module-${VER_LUA_NGINX_MODULE}
RUN curl -L https://github.com/openresty/lua-nginx-module/archive/v${VER_LUA_NGINX_MODULE}.tar.gz -o ${LUA_NGINX_MODULE}.tar.gz
RUN tar -xzf ${LUA_NGINX_MODULE}.tar.gz && rm ${LUA_NGINX_MODULE}.tar.gz

ENV VER_HTTP_HEADERS_MODULES=0.32
ENV HTTP_HEADERS_MODULE headers-more-nginx-module-${VER_HTTP_HEADERS_MODULES}
RUN curl -L https://github.com/openresty/headers-more-nginx-module/archive/v${VER_HTTP_HEADERS_MODULES}.tar.gz -o ${HTTP_HEADERS_MODULE}.tar.gz
RUN tar -xzf ${HTTP_HEADERS_MODULE}.tar.gz && rm ${HTTP_HEADERS_MODULE}.tar.gz

WORKDIR /LuaJIT-${VER_LUAJIT}
RUN make
RUN make install

ENV NGINX_ROOT=/
ENV LUAJIT_LIB /usr/local/lib
ENV LUAJIT_INC /usr/local/include/luajit-2.0
WORKDIR /nginx-${VER_NGINX}
RUN ./configure --prefix=${NGINX_ROOT} --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --with-threads --with-http_v2_module \
    --with-ld-opt="-Wl,-rpath,${LUAJIT_LIB}" --add-module=/${NGINX_DEVEL_KIT} --add-module=/${LUA_NGINX_MODULE} --add-module=/${HTTP_HEADERS_MODULE}
RUN make -j2
RUN make install
RUN strip /usr/sbin/nginx*

FROM alpine:3.6
EXPOSE 80
RUN apk --no-cache upgrade
RUN apk --no-cache add curl bash pcre libgcc
RUN mkdir -p /var/cache/nginx /var/log/nginx
COPY --from=build /usr/sbin/nginx /usr/sbin/
COPY --from=build /usr/local/lib/* /usr/local/lib/
COPY --from=build /etc/nginx/* /etc/nginx/
COPY --from=build /html/* /html/
ADD https://raw.githubusercontent.com/knyar/nginx-lua-prometheus/master/prometheus.lua /var/lib/lua/
ADD nginx.conf /etc/nginx/nginx.conf
RUN ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log
STOPSIGNAL SIGTERM
CMD ["nginx", "-g", "daemon off;"]
