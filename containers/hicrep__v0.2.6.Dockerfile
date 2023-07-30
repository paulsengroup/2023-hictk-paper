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

FROM ghcr.io/paulsengroup/ci-docker-images/ubuntu-22.04-cxx-clang-15:20230707 as hicrep_hictk


ARG HICTKPY_GIT='https://github.com/paulsengroup/hictkpy.git'
ARG HICTKPY_TAG='eed5070ae2b74602d367929c39924ff871c66b97'

RUN git clone "$HICTKPY_GIT" /tmp/hictkpy \
&& cd /tmp/hictkpy \
&& git checkout "$HICTKPY_TAG"

RUN conan install "/tmp/hictkpy/conanfile.txt"   \
             --build=missing                     \
             -pr:b="$CONAN_DEFAULT_PROFILE_PATH" \
             -pr:h="$CONAN_DEFAULT_PROFILE_PATH" \
             -s build_type=Release               \
             -s compiler.libcxx=libstdc++11      \
             -s compiler.cppstd=17               \
             --output-folder=/tmp/staging        \
             -o '*/*:shared=True'                \
&& conan cache clean "*" --build    \
&& conan cache clean "*" --download \
&& conan cache clean "*" --source

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
    python3.11-dev \
    python3.11-venv

RUN python3.11 -m venv /opt/hicrep/hictkpy \
&& env CMAKE_ARGS='-DCMAKE_PREFIX_PATH=/tmp/staging' \
   /opt/hicrep/hictkpy/bin/pip install -v /tmp/hictkpy

ARG HICREP_GIT='https://github.com/robomics/hicrep.git'
ARG HICREP_TAG='5ddf67f93b40d4e0fbd455aa70461c7b47d50bd7'

RUN /opt/hicrep/hictkpy/bin/pip install "git+$HICREP_GIT@$HICREP_TAG"

RUN /opt/hicrep/hictkpy/bin/hicrep --help

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
