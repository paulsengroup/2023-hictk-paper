#!/usr/bin/env python3
import argparse
import functools
import sys
from typing import Dict

import numpy as np
import pandas as pd

# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT


def make_cli():
    cli = argparse.ArgumentParser("Read a BED file from stdin and output a BEDPE to stdout.")

    cli.add_argument("type", choices={"cis", "trans"}, type=str, help="Type of query to generate.")

    cli.add_argument("--num-queries", type=int, default=10_000, help="Number of queries to generate.")

    cli.add_argument(
        "--seed",
        type=int,
        default=2_511_044_160,
        help="Seed to use for random sampling.",
    )

    return cli


@functools.cache
def chrom_ranks() -> Dict[str, int]:
    chroms = tuple(
        [
            "chr1",
            "chr2",
            "chr3",
            "chr4",
            "chr5",
            "chr6",
            "chr7",
            "chr8",
            "chr9",
            "chr10",
            "chr11",
            "chr12",
            "chr13",
            "chr14",
            "chr15",
            "chr16",
            "chr17",
            "chr18",
            "chr19",
            "chr20",
            "chr21",
            "chr22",
            "chrX",
            "chrY",
        ]
    )

    return {c: i for i, c in enumerate(chroms)}


def generate_cis(df: pd.DataFrame, num_queries: int, seed: int) -> pd.DataFrame:
    df1 = pd.concat([df, df], axis="columns")
    df1.columns = ["chrom1", "start1", "end1", "chrom2", "start2", "end2"]

    return df1.sample(num_queries, replace=True, random_state=seed)


def generate_trans(df: pd.DataFrame, num_queries: int, seed: int) -> pd.DataFrame:
    df = df.copy()

    df_out = pd.DataFrame()

    prng = np.random.PCG64(seed)

    while len(df_out) < num_queries:
        df1 = df.sample(
            num_queries,
            replace=True,
            random_state=prng,
            axis="index",
            ignore_index=True,
        )
        prng = prng.jumped()
        df2 = df.sample(
            num_queries,
            replace=True,
            random_state=prng,
            axis="index",
            ignore_index=True,
        )
        prng = prng.jumped()

        df3 = pd.concat([df1, df2], axis="columns")
        df3.columns = ["chrom1", "start1", "end1", "chrom2", "start2", "end2"]
        df3["rank1"] = df3["chrom1"].map(lambda chrom: chrom_ranks().get(chrom))
        df3["rank2"] = df3["chrom2"].map(lambda chrom: chrom_ranks().get(chrom))

        df3 = df3.dropna()

        df3 = df3[df3["rank1"] < df3["rank2"]]

        if len(df_out) == 0:
            df_out = df3.drop_duplicates()
            continue

        df_out = pd.concat([df_out, df3]).drop_duplicates()

    return df_out.sample(num_queries, replace=False, random_state=prng.jumped()).drop(columns=["rank1", "rank2"])


def main():
    args = vars(make_cli().parse_args())
    df = pd.read_table(sys.stdin, usecols=[0, 1, 2], names=["chrom", "start", "end"])

    if args["type"] == "cis":
        df = generate_cis(df, args["num_queries"], args["seed"])
    else:
        df = generate_trans(df, args["num_queries"], args["seed"])

    df.to_csv(sys.stdout, sep="\t", header=False, index=False)


if __name__ == "__main__":
    main()
