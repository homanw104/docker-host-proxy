FROM alpine:latest

# RUN sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories

RUN addgroup -S redsocks && adduser -S redsocks -G redsocks
RUN apk update && apk add --no-cache \
    iproute2-ss \
    redsocks \
    iptables \
    && rm -rf /var/cache/apk/*

COPY redsocks.conf /etc/redsocks/redsocks.conf
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
