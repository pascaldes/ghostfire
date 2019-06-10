ARG ALPINE_VERSION="3.9"
ARG NODE_VERSION="10.16-alpine"

# Node official layer
### ### ### ### ### ### ### ### ### ### ###
FROM node:${NODE_VERSION} AS node-official

WORKDIR /usr/local/bin

RUN set -eux                                                      && \
    apk --update --no-cache add \
      upx                                                         && \
    upx node                                                      ;
    # node size / before=39.8MO, after=14.2MO
    # Thanks for the idea https://github.com/mhart/alpine-node/blob/master/slim/Dockerfile :)

# Node slim layer (about 50MO lighter)
### ### ### ### ### ### ### ### ### ### ###
FROM alpine:${ALPINE_VERSION} AS node-slim

LABEL org.label-schema.ghost.node-version="${NODE_VERSION}"       \
      org.label-schema.ghost.alpine-version="${ALPINE_VERSION}"   \
      org.label-schema.ghost.maintainer="${MAINTAINER}"           \
      org.label-schema.schema-version="1.0"

RUN set -eux                                                      && \
# setup node user and group
    addgroup -g 1000 node                                         \
    && adduser -u 1000 -G node -s /bin/sh -D node                 ;

# install node without yarn, npm, npx, etc.
COPY --from=node-official /usr/local/bin/node /usr/bin/
COPY --from=node-official /usr/lib/libgcc* /usr/lib/libstdc* /usr/lib/