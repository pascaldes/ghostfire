### ### ### ### ### ### ### ### ###
# binary layer
### ### ### ### ### ### ### ### ###
FROM devmtl/ghostfire:2.23.2-454150d AS ghost-binary
COPY --from=ghost-builder --chown=node:node "${GHOST_INSTALL}" "${GHOST_INSTALL}"

RUN apk --update --no-cache add \
  libstdc++ \
  ca-certificates \
  binutils-gold \
  g++ \
  gcc \
  gnupg \
  libgcc \
  linux-headers \
  make \
  python \
  upx

WORKDIR /var/lib/ghost/versions/"${GHOST_VERSION}"

RUN echo; pwd; echo; ls -AlhF; echo; du -sh *; echo; du -sh && \
npm install nexe -g && \
nexe --build -c="--fully-static" --logLevel verbose --input index.js --output ghostapp;

RUN chmod a+x ghostapp && \
echo; pwd; echo; ls -AlhF; echo; du -sh *; echo; du -sh;

### ### ### ### ### ### ### ### ###
# Final layer
# USER $GHOST_USER // bypassed as it causes all kinds of permission issues
# HEALTHCHECK CMD wget -q -s http://localhost:2368 || exit 1 // bypassed as attributes are passed during runtime <docker service create>
### ### ### ### ### ### ### ### ###
FROM alpine:3.9 AS ghost-final

RUN set -eux                                    && \
    apk --update --no-cache add 'su-exec>=0.2'  \
        bash curl tini                          && \
    rm -rf /var/cache/apk/*;

COPY --from=ghost-binary --chown=node:node "${GHOST_INSTALL}" "${GHOST_INSTALL}"
COPY docker-entrypoint.sh /usr/local/bin
COPY Dockerfile /usr/local/bin
COPY README.md /usr/local/bin

# RUN /usr/bin/upx /var/lib/ghost/versions/2.23.2/ghostapp

WORKDIR "${GHOST_INSTALL}"
VOLUME "${GHOST_CONTENT}"
EXPOSE 2368

ENTRYPOINT [ "/sbin/tini", "--", "docker-entrypoint.sh" ]
CMD [ "ghostapp" ]
