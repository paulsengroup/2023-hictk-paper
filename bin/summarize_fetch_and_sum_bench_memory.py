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

    return cli


def main():
    args = vars(make_cli().parse_args())

    cols = ["tool", "format", "resolution"]
    dfs = [pd.read_table(path).set_index(cols)[["memory"]] for path in args["tsvs"]]
    df1 = pd.concat(dfs, axis="columns")
    df = pd.DataFrame(index=df1.index)

    df["mean"] = df1.mean(axis="columns")
    df["std"] = df1.std(axis="columns")
    df["median"] = df1.median(axis="columns")

    df.to_csv(sys.stdout, sep="\t", index=True, header=True)


if __name__ == "__main__":
    main()
