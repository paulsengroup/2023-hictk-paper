#!/usr/bin/env bash

# Copyright (C) 2024 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

if [ $# -ne 7 ]; then
  2>&1 echo "Usage:   $0 path_to_pairs path_to_output tmpdir hic_tools.jar resolution cpus memory"
  2>&1 echo "Example: $0 pairs.4dn.gz out.hic tmp/ hic_tools.jar 1000000 16 650G"
  exit 1
fi

path_to_pairs="$1"
path_to_output="$2"
tmpdir="$(mktemp -d -t "$3/hictk-tmp-XXXXXXXXXX")"
hic_tools_jar="$4"
resolution="$5"
cpus="$6"
memory="$7"


trap 'rm -rf -- "$tmpdir"' EXIT

java -jar -"Xmx${memory}" "$hic_tools_jar" \
    pre "$path_to_pairs" "$path_to_output" \
    hg38 \
    -r "$resolution" \
    -n \
    -t "$tmpdir" \
    -j "$cpus" \
    --threads "$cpus"
