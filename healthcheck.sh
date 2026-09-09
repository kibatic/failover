#!/bin/sh
set -u

INTERVAL="${HEALTH_INTERVAL:-5}"
TIMEOUT="${HEALTH_TIMEOUT:-3}"
FAIL_THRESHOLD="${HEALTH_FAIL_THRESHOLD:-2}"
PASS_THRESHOLD="${HEALTH_PASS_THRESHOLD:-2}"
URL="http://${UPSTREAM_HOST}:${UPSTREAM_PORT}${HEALTH_PATH:-/}"
CONF_DIR=/etc/nginx/conf.d
AVAILABLE_DIR=/etc/nginx/available

fails=0
passes=0
mode=maintenance

switch_to() {
    target="$1"
    [ "$mode" = "$target" ] && return
    ln -sf "$AVAILABLE_DIR/$target.conf" "$CONF_DIR/default.conf"
    nginx -s reload
    mode="$target"
    echo "$(date -Iseconds) [healthcheck] bascule vers $target"
}

echo "$(date -Iseconds) [healthcheck] surveillance de $URL (intervalle ${INTERVAL}s, seuils fail=${FAIL_THRESHOLD} pass=${PASS_THRESHOLD})"

while true; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "$URL" || echo 000)

    if [ "$code" = "200" ]; then
        passes=$((passes + 1))
        fails=0
    else
        fails=$((fails + 1))
        passes=0
    fi

    if [ "$mode" != "proxy" ] && [ "$passes" -ge "$PASS_THRESHOLD" ]; then
        switch_to proxy
    elif [ "$mode" != "maintenance" ] && [ "$fails" -ge "$FAIL_THRESHOLD" ]; then
        switch_to maintenance
    fi

    sleep "$INTERVAL"
done
