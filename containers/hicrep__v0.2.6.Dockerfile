# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM ubuntu:22.04 as hicrep

ARG HICREP_GIT='https://github.com/robomics/hicrep.git'
ARG HICREP_TAG='dffae463cccef470000492fc36630daf7ec55225'

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
    git \
    python3.11 \
    python3.11-venv \
&& python3.11 -m venv /opt/hicrep/vanilla \
&& /opt/hicrep/vanilla/bin/pip install "git+$HICREP_GIT@$HICREP_TAG"

RUN /opt/hicrep/vanilla/bin/hicrep --help

FROM ghcr.io/paulsengroup/ci-docker-images/ubuntu-22.04-cxx-clang-17:20240318 as hicrep_hictk


ARG HICREP_GIT='https://github.com/robomics/hicrep.git'
ARG HICREP_TAG='0055efce06e0e0335b37859076c0241ff8845ee6'

RUN python3.11 -m venv /opt/hicrep/hictkpy \
&& /opt/hicrep/hictkpy/bin/pip install "git+$HICREP_GIT@$HICREP_TAG"

RUN /opt/hicrep/hictkpy/bin/hicrep --help

RUN mkdir -p /root/.conan2/p

FROM ubuntu:22.04 as base

COPY --from=hicrep       /opt/hicrep      /opt/hicrep
COPY --from=hicrep_hictk /opt/hicrep      /opt/hicrep
COPY --from=hicrep_hictk /root/.conan2/p  /root/.conan2/p

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
    procps \
    python3.11 \
    time \
&& rm -rf /var/lib/apt/lists/*

RUN ln -s /opt/hicrep/vanilla/bin/hicrep /usr/local/bin/hicrep \
&&  ln -s /opt/hicrep/hictkpy/bin/hicrep /usr/local/bin/hicrep_hictkpy

WORKDIR /data

RUN hicrep --help
RUN hicrep_hictkpy --help

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-hicrep}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
