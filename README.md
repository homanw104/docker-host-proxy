# Docker Host Proxy

A simple container designed to transparent-proxy other containers in **host network**.

It's useful if you want to:

* Proxy containers who don't follow environment variables like `http_proxy`
* Transparent-proxy any process that runs in the host network

One of the use cases is to proxy the home-assistant container, so that the HACS plugin can use proxy while keeping the benefit of using the host network in Home Assistant.

## Features

* A relatively small size of ~18MB
* Easy configuration via environment variables
* Decoupled from your main services, redirect rules are deleted when the container stops

## Usage

1. Run your existing service with a specific user (`-u <name|uid>[:<group|gid>]`).

    ```bash
    docker run --rm -d -u 1099 --network=host <your-service>
    ```

2. Run `docker-host-proxy` with your proxy settings.

    ```bash
    docker run --rm -d --network=host \
        --cap-add NET_ADMIN \
        --cap-add NET_RAW \
        -e PROXIED_UID=1099 \
        -e PROXY_SERVER=127.0.0.1 \
        -e PROXY_PORT=7897 \
        homanw104/docker-host-proxy:latest
    ```

## Docker Compose

Alternatively, you can simply add the proxy service to your docker compose file.

```yml
services:
  your-service:
    image: <your-service>
    network_mode: host

    # Designate a user for your existing services that you want to proxy.
    # It must be the same as the PROXIED_UID set in the proxy container
    # and it will be used to add specific iptables rules.
    user: "1099"

  docker-host-proxy:
    image: homanw104/docker-host-proxy:latest
    network_mode: host
    environment:
      - PROXIED_UID=1099
      - PROXY_SERVER=127.0.0.1
      - PROXY_PORT=7897
      # Other optional variables available
      # - LOG_DEBUG=off
      # - LOG_INFO=on
      # - LOCAL_IP=127.0.0.1
      # - LOCAL_PORT=17777
      # - PROXY_TYPE=socks5
    cap_add:
      - NET_ADMIN
      - NET_RAW
```
