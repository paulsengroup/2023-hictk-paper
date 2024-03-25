# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM ghcr.io/paulsengroup/hictk:0.0.11 AS base

ARG CONTAINER_VERSION

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

RUN apt-get update \
&& apt-get install -y \
      procps \
      time \
      zstd \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /data

RUN hictk --version

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-hictk-bench}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
