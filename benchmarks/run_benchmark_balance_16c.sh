#!/usr/bin/env bash

# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

set -e
set -u
set -o pipefail
set -x


step='benchmark_balance_16c'
wd=".nextflow-$step-wd"
mkdir -p "$wd"

./setup_workflow_workdir.sh "$PWD" "$wd"
./run_benchmark_workflow.sh "$wd" "$step"
