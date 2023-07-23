# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM ubuntu:22.04 AS base


ARG CONTAINER_VERSION
ARG COOLER_VERSION="${CONTAINER_VERSION}"
ARG PIP_NO_CACHE_DIR=0

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    procps \
&& pip install "cooler==$COOLER_VERSION" \
&& apt-get remove -y python3-pip \
&& rm -rf /var/lib/apt/lists/*

CMD ["cooler"]
WORKDIR /data

RUN cooler --version

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-cooler}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
