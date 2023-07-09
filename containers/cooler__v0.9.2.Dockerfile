# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

FROM mambaorg/micromamba:1.4.7 AS base

ARG MAMBA_DOCKERFILE_ACTIVATE=1

ARG CONTAINER_VERSION
ARG COOLER_VERSION="${CONTAINER_VERSION}"

RUN if [ -z "$CONTAINER_VERSION" ]; then echo "Missing CONTAINER_VERSION --build-arg" && exit 1; fi

RUN micromamba install -y \
               -c conda-forge \
               -c bioconda \
               "cooler=$COOLER_VERSION" \
               procps-ng \
&& micromamba clean --all -y

ENV MKL_NUM_THREADS=1
ENV NUMEXPR_NUM_THREADS=1
ENV OMP_NUM_THREADS=1

ENV PATH="/opt/conda/bin:$PATH"
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]
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
