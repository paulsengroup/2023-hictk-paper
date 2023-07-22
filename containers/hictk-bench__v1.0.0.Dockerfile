# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM curlimages/curl:8.2.0 AS downloader

ARG CONTAINER_VERSION
ARG HICTOOLS_VER=3.30.00


ARG HICTOOLS_URL="https://github.com/aidenlab/HiCTools/releases/download/v${HICTOOLS_VER}/hic_tools.${HICTOOLS_VER}.jar"
ARG HICTOOLS_SHA256='2b09b0642a826ca5730fde74e022461a708caf62ed292bc5baaa841946721867'

RUN cd /tmp \
&& curl -LO "$HICTOOLS_URL" \
&& curl -L 'https://raw.githubusercontent.com/aidenlab/HiCTools/6b2fab8e78685deae199c33bbb167dcab1dbfbb3/LICENSE' -o hic_tools.LICENSE \
&& echo "$HICTOOLS_SHA256  $(basename "$HICTOOLS_URL")" >> checksum.sha256 \
&& sha256sum -c checksum.sha256 \
&& chmod 644 *.jar *LICENSE


FROM ghcr.io/paulsengroup/hictk:sha-ff13ce0 AS base

ARG CONTAINER_VERSION

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

COPY --from=downloader  --chown=root:root /tmp/hic_tools*.jar                 /usr/local/share/java/hic_tools/
COPY --from=downloader  --chown=root:root /tmp/hic_tools.LICENSE              /usr/local/share/licenses/hic_tools/LICENSE

RUN ln -s /usr/local/share/java/hic_tools/hic_tools*.jar /usr/local/share/java/hic_tools/hic_tools.jar
ENV HICTOOLS_JAR=/usr/local/share/java/hic_tools/hic_tools.jar

RUN apt-get update \
&& apt-get install -y \
      openjdk-19-jre-headless \
      pigz \
      procps \
      time \
      zstd \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /data

RUN hictk --version
RUN java -jar "$HICTOOLS_JAR"

LABEL org.opencontainers.image.authors='Roberto Rossini <roberros@uio.no>'
LABEL org.opencontainers.image.url='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.documentation='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.source='https://github.com/paulsengroup/2023-hictk-paper'
LABEL org.opencontainers.image.licenses='MIT'
LABEL org.opencontainers.image.title="${CONTAINER_TITLE:-hictk-bench}"
LABEL org.opencontainers.image.version="${CONTAINER_VERSION:-latest}"
