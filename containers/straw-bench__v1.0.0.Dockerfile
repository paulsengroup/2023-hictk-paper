# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT


FROM ghcr.io/paulsengroup/ci-docker-images/ubuntu-22.04-cxx-clang-15:20230707 as builder

ARG STRAW_GIT_TAG='2525edc29bbb48463799cad94cbd6e5e810210a0'

RUN apt-get update \
&& apt-get install -y \
    libcurl4-openssl-dev \
    zlib1g-dev \
&& cd /tmp \
&& git clone https://github.com/aidenlab/straw.git \
&& cd straw/ \
&& git checkout "$STRAW_GIT_TAG" \
&& cmake -DCMAKE_BUILD_TYPE=Release \
    -S /tmp/straw/C++ \
    -B /tmp/build \
&& cmake --build /tmp/build -j "$(nproc)"

FROM ubuntu:22.04 AS base

ARG CONTAINER_VERSION

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

COPY --from=builder --chown=root:root /tmp/build/straw       /usr/local/bin/straw
COPY --from=builder --chown=root:root /tmp/straw/LICENSE     /usr/local/share/licenses/straw/LICENSE

RUN apt-get update \
&& apt-get install -y \
      libcurl4 \
      procps \
      time \
      zlib1g \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /data

RUN whereis straw

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-straw-bench}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
