#!/usr/bin/env python3

# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

import argparse
import sys

import pandas as pd


def make_cli():
    cli = argparse.ArgumentParser()

    cli.add_argument(
        "tsvs",
        nargs="+",
        type=str,
        help="Path to two or more tsvs to be summarized.",
    )

    cli.add_argument("--tool", type=str, required=True)
    cli.add_argument("--format", type=str, required=True)
    cli.add_argument("--resolution", type=int, required=True)

    return cli


def main():
    args = vars(make_cli().parse_args())

    cols = ["chrom1", "start1", "end1", "chrom2", "start2", "end2"]
    dfs = [pd.read_table(path).set_index(cols)[["time"]] for path in args["tsvs"]]
    df1 = pd.concat(dfs, axis="columns")

    df = pd.DataFrame(index=df1.index)

    df["mean"] = df1.mean(axis="columns")
    df["std"] = df1.std(axis="columns")
    df["median"] = df1.median(axis="columns")
    df["tool"] = args["tool"]
    df["format"] = args["format"]
    df["resolution"] = args["resolution"]

    df.to_csv(sys.stdout, sep="\t", index=True, header=True)


if __name__ == "__main__":
    main()
