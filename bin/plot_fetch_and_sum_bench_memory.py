#!/usr/bin/env python3

# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

import argparse
import pathlib
import sys

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns


def make_cli():
    cli = argparse.ArgumentParser()

    cli.add_argument(
        "tsvs",
        nargs="+",
        type=str,
        help="Path to tsvs with data for plotting.",
    )
    cli.add_argument("--query-type", type=str, required=True)

    cli.add_argument("--output-prefix", type=pathlib.Path)

    return cli


def compute_performance_ratio(df: pd.DataFrame) -> pd.DataFrame:
    # Find the fastest tool on average
    baseline_tool = df.groupby("tool")["median"].mean().idxmax()

    # Compute mean runtime for each tool and resolution
    tools = []
    resolutions = []
    medians = []
    for (tool, resolution), median in df.groupby(["tool", "resolution"])["median"]:
        tools.append(tool)
        resolutions.append(resolution)
        medians.append(median.mean())

    # Compute the baseline for each tool and resolution
    df1 = pd.DataFrame({"tool": tools, "resolution": resolutions, "median": medians})
    baselines = {}
    for res, df2 in df1.groupby("resolution"):
        baseline = df2.loc[df2["tool"] == baseline_tool, "median"]
        assert len(baseline) == 1
        baselines[res] = baseline.iloc[0]

    # Divide runtimes by their respective baselines
    for res in df["resolution"].unique():
        df1.loc[df1["resolution"] == res, "median"] = baselines[res] / df1.loc[df1["resolution"] == res, "median"]

    return df1


def plot_ratio(df: pd.DataFrame, query_type: str, out_prefix: pathlib.Path):
    fig, ax = plt.subplots(1, 1)

    sns.barplot(df, x="resolution", y="median", hue="tool", errorbar="std", ax=ax)
    ax.set(
        title=f"Random queries relative performance ({query_type})",
        ylabel="relative speed",
        xlabel="Resolution (bp)",
    )

    ax.tick_params(axis="x", rotation=45)

    plt.tight_layout()
    fig.savefig(out_prefix.with_suffix(".png"), dpi=300)
    fig.savefig(out_prefix.with_suffix(".svg"))


def main():
    args = vars(make_cli().parse_args())

    files = args["tsvs"]

    df = pd.concat((pd.read_table(path) for path in files))
    df["tool"] = df["tool"] + "_" + df["format"]

    fig, ax = plt.subplots(1, 1)
    sns.barplot(df, x="resolution", y="median", hue="tool", ax=ax)
    ax.tick_params(axis="x", rotation=45)

    plt.tight_layout()
    fig.savefig(args["output_prefix"].with_suffix(".png"), dpi=300)
    fig.savefig(args["output_prefix"].with_suffix(".svg"))


if __name__ == "__main__":
    main()
