# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM ghcr.io/paulsengroup/ci-docker-images/ubuntu-22.04-cxx-clang-17:20240306 as builder

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



FROM curlimages/curl:8.5.0 AS downloader

ARG CONTAINER_VERSION
ARG HICTOOLS_VER=${CONTAINER_VERSION}

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi


ARG HICTOOLS_URL="https://github.com/aidenlab/HiCTools/releases/download/v${HICTOOLS_VER}/hic_tools.${HICTOOLS_VER}.jar"
ARG HICTOOLS_SHA256='2b09b0642a826ca5730fde74e022461a708caf62ed292bc5baaa841946721867'

RUN cd /tmp \
&& curl -LO "$HICTOOLS_URL" \
&& curl -L 'https://raw.githubusercontent.com/aidenlab/HiCTools/6b2fab8e78685deae199c33bbb167dcab1dbfbb3/LICENSE' -o hic_tools.LICENSE \
&& echo "$HICTOOLS_SHA256  $(basename "$HICTOOLS_URL")" >> checksum.sha256 \
&& sha256sum -c checksum.sha256 \
&& chmod 644 *.jar *LICENSE

FROM ubuntu:22.04 AS base

ARG CONTAINER_VERSION

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi


COPY --from=downloader  --chown=root:root /tmp/hic_tools*.jar                 /usr/local/share/java/hic_tools/
COPY --from=downloader  --chown=root:root /tmp/hic_tools.LICENSE              /usr/local/share/licenses/hic_tools/LICENSE
COPY --from=builder --chown=root:root /tmp/staging/bin/4dn_pairs_to_txt       /usr/local/bin/4dn_pairs_to_txt

RUN ln -s /usr/local/share/java/hic_tools/hic_tools*.jar /usr/local/share/java/hic_tools/hic_tools.jar
ENV HICTOOLS_JAR=/usr/local/share/java/hic_tools/hic_tools.jar

RUN apt-get update \
&& apt-get install -y openjdk-19-jre-headless pigz procps time \
&& rm -rf /var/lib/apt/lists/*

ENV MKL_NUM_THREADS=1
ENV NUMEXPR_NUM_THREADS=1
ENV OMP_NUM_THREADS=1

WORKDIR /data

RUN java -jar "$HICTOOLS_JAR"
RUN which 4dn_pairs_to_txt

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-hic-tools}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
