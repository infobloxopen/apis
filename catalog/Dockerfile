ARG CREATED
ARG REVISION
ARG SOURCE
ARG VERSION

FROM scratch

LABEL org.opencontainers.image.title="API Catalog" \
      org.opencontainers.image.description="APX API catalog data for discovery and search" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.vendor="infobloxopen" \
      dev.apx.type="catalog"

COPY catalog.yaml /catalog.yaml
