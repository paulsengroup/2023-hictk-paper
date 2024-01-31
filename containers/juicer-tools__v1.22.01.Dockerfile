# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT


FROM ghcr.io/paulsengroup/ci-docker-images/ubuntu-22.04-cxx-clang-17:20240126 as builder

COPY utils /tmp/utils

RUN conan install /tmp/utils/conanfile.txt               \
                  --build=missing                        \
                  -pr:b="$CONAN_DEFAULT_PROFILE_PATH"    \
                  -pr:h="$CONAN_DEFAULT_PROFILE_PATH"    \
                  -s build_type=Release                  \
                  -s compiler.libcxx=libstdc++11         \
                  -s compiler.cppstd=17                  \
                  --output-folder=/tmp/build/ \
&& cmake -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_INSTALL_PREFIX=/tmp/staging \
         -DCMAKE_PREFIX_PATH=/tmp/build/ \
         -DBUILD_BENCHMARKS=OFF \
         -DBUILD_UTILS=ON \
         -S /tmp/utils/ \
         -B /tmp/build \
&& cmake --build /tmp/build -t 4dn_pairs_to_txt -j $(nproc) \
&& cmake --install /tmp/build

FROM curlimages/curl:8.6.0 AS downloader

ARG CONTAINER_VERSION
ARG JUICERTOOLS_VER=${CONTAINER_VERSION}

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi


ARG JUICERTOOLS_URL="https://s3.amazonaws.com/hicfiles.tc4ga.com/public/juicer/juicer_tools_${JUICERTOOLS_VER}.jar"
ARG JUICERTOOLS_SHA256='5bd863e1fbc4573de09469e0adc5ab586e2b75b14dd718465e14dc299d7243a0'

RUN cd /tmp \
&& curl -LO "$JUICERTOOLS_URL" \
&& curl -L 'https://raw.githubusercontent.com/aidenlab/juicer/1c414ddebc827849f9c09fe2d2a2ea7c9a8c78df/LICENSE' -o juicer_tools.LICENSE \
&& echo "$JUICERTOOLS_SHA256  $(basename "$JUICERTOOLS_URL")" > checksum.sha256 \
&& sha256sum -c checksum.sha256 \
&& chmod 644 *.jar *LICENSE

FROM ubuntu:22.04 AS base

ARG CONTAINER_VERSION

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi


COPY --from=downloader  --chown=root:root /tmp/juicer_tools*.jar              /usr/local/share/java/juicer_tools/
COPY --from=downloader  --chown=root:root /tmp/juicer_tools.LICENSE           /usr/local/share/licenses/juicer_tools/LICENSE
COPY --from=builder --chown=root:root /tmp/staging/bin/4dn_pairs_to_txt       /usr/local/bin/4dn_pairs_to_txt

RUN ln -s /usr/local/share/java/juicer_tools/juicer_tools*.jar /usr/local/share/java/juicer_tools/juicer_tools.jar
ENV JUICERTOOLS_JAR=/usr/local/share/java/juicer_tools/juicer_tools.jar

RUN apt-get update \
&& apt-get install -y openjdk-19-jre-headless pigz procps \
&& rm -rf /var/lib/apt/lists/*

ENV MKL_NUM_THREADS=1
ENV NUMEXPR_NUM_THREADS=1
ENV OMP_NUM_THREADS=1

WORKDIR /data

RUN java -jar "$JUICERTOOLS_JAR"
RUN which 4dn_pairs_to_txt

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-juicer-tools}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
