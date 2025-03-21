#!/bin/sh

# Set defaults for optional variables
LOG_DEBUG=${LOG_DEBUG:-off}
LOG_INFO=${LOG_INFO:-on}
LOCAL_IP=${LOCAL_IP:-127.0.0.1}
LOCAL_PORT=${LOCAL_PORT:-17777}
PROXY_TYPE=${PROXY_TYPE:-socks5}

check_variables() {
    echo "Checking environment variables..."

    if [ -z "$PROXIED_UID" ]; then echo "Error: You must define the PROXIED_UID."; exit 1; fi
    if [ -z "$PROXY_SERVER" ]; then echo "Error: You must define the PROXY_SERVER."; exit 1; fi
    if [ -z "$PROXY_PORT" ]; then echo "Error: You must define the PROXY_PORT."; exit 1; fi

    echo "- PROXIED_UID=$PROXIED_UID"
    echo "- PROXY_SERVER=$PROXY_SERVER"
    echo "- PROXY_PORT=$PROXY_PORT"
    echo "- LOG_DEBUG=$LOG_DEBUG"
    echo "- LOG_INFO=$LOG_INFO"
    echo "- LOCAL_IP=$LOCAL_IP"
    echo "- LOCAL_PORT=$LOCAL_PORT"
    echo "- PROXY_TYPE=$PROXY_TYPE"
}

check_port_avail() {
    echo "Checking local port availability..."

    # Check for the next available local port
    while ss -tuln | grep ":$LOCAL_PORT" >/dev/null; do
        echo "- Port $LOCAL_PORT is in use"
        LOCAL_PORT=$((LOCAL_PORT+1))
    done

    echo "- Using local port $LOCAL_PORT"
}

setup_redsocks() {
    echo "Setting up redsocks config..."

    sed -i "s/\$LOG_DEBUG/$LOG_DEBUG/g" /etc/redsocks/redsocks.conf
    sed -i "s/\$LOG_INFO/$LOG_INFO/g" /etc/redsocks/redsocks.conf
    sed -i "s/\$LOCAL_IP/$LOCAL_IP/g" /etc/redsocks/redsocks.conf
    sed -i "s/\$LOCAL_PORT/$LOCAL_PORT/g" /etc/redsocks/redsocks.conf
    sed -i "s/\$PROXY_TYPE/$PROXY_TYPE/g" /etc/redsocks/redsocks.conf
    sed -i "s/\$PROXY_SERVER/$PROXY_SERVER/g" /etc/redsocks/redsocks.conf
    sed -i "s/\$PROXY_PORT/$PROXY_PORT/g" /etc/redsocks/redsocks.conf

    # Remove login and password if either is unset
    if [ -z "$LOGIN" ] || [ -z "$PASSWORD" ]; then
        sed -i '/login = /d' /etc/redsocks/redsocks.conf
        sed -i '/password = /d' /etc/redsocks/redsocks.conf
    fi
}

setup_iptables() {
    echo "Setting up iptables rules..."

    # Create new chain
    chain_name=REDSOCKS-$LOCAL_PORT
    iptables -t nat -N $chain_name

    # Ignore LANs and some other reserved addresses
    iptables -t nat -A $chain_name -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A $chain_name -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A $chain_name -d 100.64.0.0/10 -j RETURN
    iptables -t nat -A $chain_name -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A $chain_name -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A $chain_name -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A $chain_name -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A $chain_name -d 198.18.0.0/15 -j RETURN
    iptables -t nat -A $chain_name -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A $chain_name -d 240.0.0.0/4 -j RETURN

    # Anything else should be redirected to redsocks
    iptables -t nat -A $chain_name -p tcp -j REDIRECT --to-ports $LOCAL_PORT

    # Redirect tcp connections made by specific user to the chain
    iptables -t nat -A OUTPUT -p tcp -m owner --uid-owner $PROXIED_UID -j $chain_name
}

cleanup() {
    # Delete redsocks-related iptables rules
    iptables -t nat -D OUTPUT -p tcp -m owner --uid-owner $PROXIED_UID -j $chain_name
    iptables -t nat -F $chain_name
    iptables -t nat -X $chain_name
}

trap 'code=$?; cleanup; exit $code' ERR # Clean up and return error code when there is an error
trap 'cleanup; exit 143' SIGTERM        # Return 143 indicates a successful SIGTERM kill (e.g. `docker stop`)

check_variables
check_port_avail
setup_redsocks
setup_iptables

/usr/bin/redsocks -c /etc/redsocks/redsocks.conf & wait $!
