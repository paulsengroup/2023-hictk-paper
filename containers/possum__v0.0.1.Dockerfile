# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT


FROM ghcr.io/paulsengroup/ci-docker-images/ubuntu-22.04-cxx-clang-15:20230707 as builder

ARG POSSUM_GIT='https://github.com/robomics/EigenVector.git'
ARG POSSUM_PATCHED_TAG='eba7fb5be7dc14da2f56cb2894a3f14339c43a7e'
ARG POSSUM_HICTK_TAG='c45ec4646e7657ba69bae0e9b3cce315814b4cb5'

RUN apt-get update \
&& apt-get install -y \
    libcurl4-openssl-dev \
    zlib1g-dev

RUN git clone "$POSSUM_GIT" /tmp/possum \
&& cd /tmp/possum/ \
&& git checkout "$POSSUM_PATCHED_TAG" \
&& cmake -DCMAKE_BUILD_TYPE=Release \
         -S /tmp/possum \
         -B /tmp/build_patched \
&& cmake --build /tmp/build_patched -j "$(nproc)"

RUN cd /tmp/possum \
&& git checkout "$POSSUM_HICTK_TAG"

RUN conan install "/tmp/possum/conanfile.txt"    \
             --build=missing                     \
             -pr:b="$CONAN_DEFAULT_PROFILE_PATH" \
             -pr:h="$CONAN_DEFAULT_PROFILE_PATH" \
             -s build_type=Release               \
             -s compiler.libcxx=libstdc++11      \
             -s compiler.cppstd=17               \
             --output-folder=/tmp/staging

RUN cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_PREFIX_PATH=/tmp/staging \
          -S /tmp/possum \
          -B /tmp/build_hictk \
&& cmake --build /tmp/build_hictk -j "$(nproc)"

FROM ubuntu:22.04 AS base

ARG CONTAINER_VERSION

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

COPY --from=builder --chown=root:root '/tmp/build_patched/C++/PowerMethod/POSSUM_power' /usr/local/bin/POSSUM_power
COPY --from=builder --chown=root:root '/tmp/build_hictk/C++/PowerMethod/POSSUM_power'   /usr/local/bin/POSSUM_power_hictk

RUN apt-get update \
&& apt-get install -y \
      libcurl4 \
      procps \
      time \
      zlib1g \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /data

RUN whereis POSSUM_power
RUN whereis POSSUM_power_hictk

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-possum}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
