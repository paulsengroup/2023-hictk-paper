#!/usr/bin/env python3

# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

import argparse
import sys
import time

import hicstraw


def make_cli():
    cli = argparse.ArgumentParser()

    cli.add_argument(
        "uri",
        type=str,
        help="Path to a .hic file.",
    )
    cli.add_argument("resolution", type=int, help="Resolution to use for benchmarking.")

    return cli


def fetch_and_sum_hic(
    selector: hicstraw.MatrixZoomData, start1: int, end1: int, start2: int, end2: int
) -> float:
    return selector.getRecordsAsMatrix(start1, end1, start2, end2).sum()


def benchmark_hic(args):
    hf = hicstraw.HiCFile(args["uri"])

    print("chrom1\tstart1\tend1\tchrom2\tstart2\tend2\tsum\ttime")
    mzd = {}
    for line in sys.stdin:
        chrom1, start1, end1, chrom2, start2, end2 = line.split("\t")[:6]

        if (chrom1, chrom2) not in mzd:
            mzd[(chrom1, chrom2)] = hf.getMatrixZoomData(
                chrom1, chrom2, "observed", "NONE", "BP", args["resolution"]
            )

        sel = mzd[(chrom1, chrom2)]
        t0 = time.time()
        sum_ = fetch_and_sum_hic(sel, int(start1), int(end1), int(start2), int(end2))
        t1 = time.time()

        print(f"{line.strip()}\t{sum_}\t{t1 - t0}")


def main():
    args = vars(make_cli().parse_args())
    benchmark_hic(args)


if __name__ == "__main__":
    main()
