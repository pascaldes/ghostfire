# Forked from official Ghost image https://bit.ly/2JWOTam

ARG GHOST_VERSION="2.23.3"
ARG GHOST_CLI_VERSION="1.11.0"
ARG NODE_VERSION="10.16-alpine"
ARG ALPINE_VERSION="3.9"

# Node official layer
### ### ### ### ### ### ### ### ### ### ###
FROM node:${NODE_VERSION} AS node-official

WORKDIR /usr/local/bin

RUN set -eux                                                      && \
    apk --update --no-cache add \
      'su-exec>=0.2' \
      bash \
      curl \
      upx \
      tini                                                        ;

RUN set -eux                                                      && \
    upx node                                                      && \
    upx /usr/lib/libstdc*                                         ;
    # node size: before=39.8MO, after=14.2MO
    # libstdc++ size: before=1.3MO, after=983K
    # Thanks for the idea https://github.com/mhart/alpine-node/blob/master/slim/Dockerfile :)

RUN set -eux                                                      && \
    upx /bin/bash                                                 && \
    upx /usr/bin/curl                                             && \
    upx /sbin/tini                                                ;

# Node slim layer
### ### ### ### ### ### ### ### ### ### ###
FROM alpine:${ALPINE_VERSION} AS node-slim

RUN set -eux                                                      && \
    \
# setup node user and group
    addgroup -g 1000 node                                         \
    && adduser -u 1000 -G node -s /bin/sh -D node                 && \
    \
# install required apps
    apk --update --no-cache add \
      'su-exec>=0.2' \
      bash \
      curl \
      tini                                                        && \
    rm -rf /var/cache/apk/*                                       ;

# install compressed node without yarn, npm, etc.
COPY --from=node-official /usr/local/bin/node /usr/bin/
COPY --from=node-official /usr/lib/libgcc* /usr/lib/libstdc* /usr/lib/

# override apps with there compreseed version
COPY /bin/bash /bin/bash
COPY /usr/bin/curl /usr/bin/curl
COPY /sbin/tini /sbin/tini

# entrypoint
COPY docker-entrypoint.sh /usr/local/bin

# history (optional)
COPY Dockerfile /usr/local/bin
COPY README.md /usr/local/bin

ARG GHOST_VERSION
ARG GHOST_CLI_VERSION
ARG NODE_VERSION
ARG ALPINE_VERSION

ENV GHOST_INSTALL="/var/lib/ghost"                                \
    GHOST_CONTENT="/var/lib/ghost/content"                        \
    NODE_ENV="production"                                         \
    GHOST_USER="node"                                             \
    GHOST_VERSION=${GHOST_VERSION}                                \
    GHOST_CLI_VERSION=${GHOST_CLI_VERSION}                        \
    MAINTAINER="Pascal Andy <https://firepress.org/en/contact/>"

LABEL org.label-schema.ghost.version="${GHOST_VERSION}"           \
      org.label-schema.ghost.cli-version="${GHOST_CLI_VERSION}"   \
      org.label-schema.ghost.user="${GHOST_USER}"                 \
      org.label-schema.ghost.node-env="${NODE_ENV}"               \
      org.label-schema.ghost.node-version="${NODE_VERSION}"       \
      org.label-schema.ghost.alpine-version="${ALPINE_VERSION}"   \
      org.label-schema.ghost.maintainer="${MAINTAINER}"           \
      org.label-schema.schema-version="1.0"

# Builder layer
### ### ### ### ### ### ### ### ### ### ###
FROM node:${NODE_VERSION} AS ghost-builder

ARG GHOST_VERSION
ARG GHOST_CLI_VERSION
ARG NODE_VERSION

ENV GHOST_INSTALL="/var/lib/ghost"                                \
    GHOST_CONTENT="/var/lib/ghost/content"                        \
    NODE_ENV="production"                                         \
    GHOST_USER="node"                                             \
    GHOST_VERSION=${GHOST_VERSION}                                \
    GHOST_CLI_VERSION=${GHOST_CLI_VERSION}                        \
    MAINTAINER="Pascal Andy <https://firepress.org/en/contact/>"

RUN set -eux                                                      && \
    apk --update --no-cache add \
        'su-exec>=0.2' \
        bash \
        ca-certificates                                           && \
    update-ca-certificates                                        && \
    rm -rf /var/cache/apk/*                                       && \
    \
# install Ghost CLI
    npm install --production -g "ghost-cli@${GHOST_CLI_VERSION}"  && \
    npm cache clean --force                                       && \
    \
    mkdir -p "${GHOST_INSTALL}"                                   && \
    chown -R node:node "${GHOST_INSTALL}"                         && \
    \
# install Ghost / optional: --verbose
    su-exec node ghost install "${GHOST_VERSION}"                 \
      --db sqlite3 --no-prompt --no-stack                         \
      --no-setup --dir "${GHOST_INSTALL}"                         && \
    \
# tell Ghost to listen on all ips and not prompt for additional configuration
    cd "${GHOST_INSTALL}"                                         && \
    su-exec node ghost config --ip 0.0.0.0                        \
      --port 2368 --no-prompt --db sqlite3                        \
      --url http://localhost:2368                                 \
      --dbpath "${GHOST_CONTENT}/data/ghost.db"                   && \
    su-exec node ghost config                                     \
      paths.contentPath "${GHOST_CONTENT}"                        && \
    \
# make a config.json symlink for NODE_ENV=development (and sanity check that it's correct)
    su-exec node ln -s config.production.json \
      "${GHOST_INSTALL}/config.development.json"                  && \
    readlink -f "${GHOST_INSTALL}/config.development.json"        && \
    \
# need to save initial content for pre-seeding empty volumes
    mv "${GHOST_CONTENT}" "${GHOST_INSTALL}/content.orig"         && \
    mkdir -p "${GHOST_CONTENT}"                                   && \
    chown -R node:node "$GHOST_CONTENT"                           && \
    \
# sanity check to ensure knex-migrator was installed
    "${GHOST_INSTALL}/current/node_modules/knex-migrator/bin/knex-migrator" --version \
    \
# uninstall ghost-cli / Let's save a few bytes
    su-exec node npm uninstall -S -D -O -g                        \
      "ghost-cli@${GHOST_CLI_VERSION}"                            ;

RUN set -eux                                                      && \
# force install "sqlite3" manually since it's an optional dependency of "ghost"
# (which means that if it fails to install, like on ARM/ppc64le/s390x, the failure will be silently ignored and thus turn into a runtime error instead)
# see https://github.com/TryGhost/Ghost/pull/7677 for more details
	cd "${GHOST_INSTALL}/current"                                   ; \
# scrape the expected version of sqlite3 directly from Ghost itself
	sqlite3Version="$(npm view . optionalDependencies.sqlite3)"     ; \
	if ! su-exec node yarn add "sqlite3@$sqlite3Version" --force; then            \
# must be some non-amd64 architecture pre-built binaries aren't published for, so let's install some build deps and do-it-all-over-again
		apk add --no-cache --virtual .build-deps python make gcc g++ libc-dev;      \
		\
		su-exec node yarn add "sqlite3@$sqlite3Version" --force --build-from-source ; \
		\
		apk del --no-network .build-deps                              ; \
	fi

# Final layer
### ### ### ### ### ### ### ### ### ### ###
FROM node-slim AS ghost-final
COPY --from=ghost-builder --chown=node:node "${GHOST_INSTALL}" "${GHOST_INSTALL}"

WORKDIR "${GHOST_INSTALL}"
VOLUME "${GHOST_CONTENT}"
EXPOSE 2368

# USER $GHOST_USER // bypassed as it causes all kinds of permission issues
# HEALTHCHECK CMD wget -q -s http://localhost:2368 || exit 1 // bypassed as attributes are passed during runtime <docker service create>

ENTRYPOINT [ "/sbin/tini", "--", "docker-entrypoint.sh" ]
CMD [ "node", "current/index.js" ]
