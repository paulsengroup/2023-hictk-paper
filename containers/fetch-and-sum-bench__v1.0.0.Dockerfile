# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT


FROM ghcr.io/paulsengroup/ci-docker-images/ubuntu-22.04-cxx-clang-17:20240318 as builder

COPY conanfile.txt /tmp/
RUN conan install /tmp/conanfile.txt             \
             --build=missing                     \
             -pr:b="$CONAN_DEFAULT_PROFILE_PATH" \
             -pr:h="$CONAN_DEFAULT_PROFILE_PATH" \
             -s build_type=Release               \
             -s compiler.libcxx=libstdc++11      \
             -s compiler.cppstd=17               \
             --output-folder=/tmp/build

COPY benchmarks /tmp/benchmarks
COPY cmake /tmp/cmake
COPY external /tmp/external
COPY CMakeLists.txt /tmp/CMakeLists.txt

RUN cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/tmp/staging \
          -DCMAKE_PREFIX_PATH=/tmp/build/ \
          -DBUILD_BENCHMARKS=ON \
          -DBUILD_UTILS=OFF \
          -S /tmp/ \
          -B /tmp/build \
&& cmake --build /tmp/build -t fetch_and_sum -j $(nproc) \
&& cmake --install /tmp/build

FROM ubuntu:22.04 AS base

ARG CONTAINER_VERSION

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

COPY --from=builder --chown=root:root /tmp/staging/bin/fetch_and_sum       /usr/local/bin/fetch_and_sum
COPY benchmarks/fetch_and_sum/fetch_and_sum*.py                            /usr/local/bin/

RUN chmod 755 /usr/local/bin/*.py

ARG PIP_NO_CACHE_DIR=0

RUN apt-get update \
&& apt-get install -y \
      libcurl4 \
      python3 \
      python3-pip \
      procps \
      time \
      libcurl4-openssl-dev \
&& pip install 'cooler==0.9.2' \
               'hic-straw==1.3.1' \
&& apt-get remove -y \
      python3-pip \
      libcurl4-openssl-dev \
&& apt-get autoremove -y \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /data

RUN fetch_and_sum --help
RUN fetch_and_sum_cooler.py --help
RUN fetch_and_sum_straw.py --help

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-fetch-and-sum-bench}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
