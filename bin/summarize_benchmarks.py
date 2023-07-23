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
        help="Path to tsvs to be summarized.",
    )

    return cli


def main():
    args = vars(make_cli().parse_args())

    files = args["tsvs"]

    df = pd.concat((pd.read_table(path) for path in files), axis="index")
    df.to_csv(sys.stdout, sep="\t", index=False)


if __name__ == "__main__":
    main()
