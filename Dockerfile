FROM nginx:1.27-alpine

LABEL maintainer="Kibatic"

RUN apk add --no-cache curl

COPY html/index.template.html /etc/nginx/html-templates/index.template.html
COPY conf/proxy.conf.template /etc/nginx/templates-src/proxy.conf.template
COPY conf/maintenance.conf.template /etc/nginx/templates-src/maintenance.conf.template
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/healthcheck.sh /usr/local/bin/docker-entrypoint.sh && \
    mkdir -p /etc/nginx/available

ENV PORT=80 \
    UPSTREAM_HOST=web \
    UPSTREAM_PORT=80 \
    HEALTH_PATH=/ \
    HEALTH_INTERVAL=5 \
    HEALTH_TIMEOUT=3 \
    HEALTH_FAIL_THRESHOLD=2 \
    HEALTH_PASS_THRESHOLD=2 \
    RESPONSE_CODE=503 \
    TITLE="Site Maintenance" \
    HEADLINE="We will be back soon!" \
    MESSAGE="Sorry for the inconvenience, we are performing maintenance." \
    TEAM_NAME="The Team" \
    THEME=Light \
    LINK_COLOR="#dc8100"

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]
