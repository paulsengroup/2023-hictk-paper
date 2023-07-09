# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

import argparse
import sys
import time
from typing import Tuple

import cooler


def make_cli():
    cli = argparse.ArgumentParser()

    cli.add_argument(
        "uri",
        type=str,
        help="Path to a Cooler file (URI syntax supported).",
    )

    return cli


def bedpe_to_ucsc(bedpe: str) -> Tuple[str, str]:
    chrom1, start1, end1, chrom2, start2, end2 = bedpe.split("\t")[:6]
    return f"{chrom1}:{start1}-{end1}", f"{chrom2}:{start2}-{end2}"


def fetch_and_sum_cooler(selector, range1, range2) -> float:
    return float(selector.fetch(range1, range2)["count"].sum())


def benchmark_cooler(args):
    clr = cooler.Cooler(args["uri"])
    sel = clr.matrix(balance=False, as_pixels=True)

    for line in sys.stdin:
        range1, range2 = bedpe_to_ucsc(line)

        t0 = time.time()
        sum_ = fetch_and_sum_cooler(sel, range1, range2)
        t1 = time.time()

        print(f"{line.strip()}\t{sum_}\t{t1 - t0}")


def main():
    args = vars(make_cli().parse_args())
    benchmark_cooler(args)


if __name__ == "__main__":
    main()
