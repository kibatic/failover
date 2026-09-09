#!/bin/sh
set -eu

TEMPLATE_DIR=/etc/nginx/templates-src
AVAILABLE_DIR=/etc/nginx/available
CONF_DIR=/etc/nginx/conf.d

mkdir -p "$AVAILABLE_DIR"
rm -f "$CONF_DIR"/*.conf

# Page de maintenance : rendue une seule fois, elle ne change pas en cours de route.
envsubst '${TITLE} ${HEADLINE} ${MESSAGE} ${TEAM_NAME} ${THEME} ${LINK_COLOR}' \
    < /etc/nginx/html-templates/index.html.template \
    > /usr/share/nginx/html/maintenance.html

# Les deux confs possibles (proxy vers l'upstream / page de maintenance locale).
# On restreint explicitement la liste de substitution à nos propres variables pour
# ne pas toucher aux variables nginx ($host, $remote_addr, ...) du template proxy.
envsubst '${PORT} ${UPSTREAM_HOST} ${UPSTREAM_PORT}' \
    < "$TEMPLATE_DIR/proxy.conf.template" > "$AVAILABLE_DIR/proxy.conf"
envsubst '${PORT} ${RESPONSE_CODE}' \
    < "$TEMPLATE_DIR/maintenance.conf.template" > "$AVAILABLE_DIR/maintenance.conf"

# Démarrage prudent : maintenance tant que l'upstream n'a pas été vérifié comme sain.
ln -sf "$AVAILABLE_DIR/maintenance.conf" "$CONF_DIR/default.conf"

/usr/local/bin/healthcheck.sh &

exec nginx -g "daemon off;"
