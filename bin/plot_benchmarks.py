#!/usr/bin/env python3

# Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
#
# SPDX-License-Identifier: MIT

import argparse
import pathlib

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns


def make_cli():
    cli = argparse.ArgumentParser()

    cli.add_argument(
        "tsv",
        type=str,
        help="Path to a TSV with data for plotting.",
    )
    cli.add_argument("--title", type=str, required=True)
    cli.add_argument("--resolutions", nargs="+", type=int)

    cli.add_argument("--output-prefix", type=pathlib.Path)

    return cli


def plot_barplot(df: pd.DataFrame, x: str, y: str, title: str, out_prefix: pathlib.Path, write_labels: bool):
    fig, ax = plt.subplots(1, 1)
    df = df.copy()

    if y == "memory":
        ylabel = "Peak memory usage (MBs)"
    elif y == "time":
        ylabel = "Time (s)"
    else:
        ylabel = y

    sns.barplot(df, x=x, y=y, hue="tool", estimator="median", ax=ax)
    ax.set(
        title=title,
        ylabel=ylabel,
        xlabel=x,
    )
    ax.tick_params(axis="x", rotation=45)

    if write_labels:
        for container in ax.containers:
            ax.bar_label(container, fmt="%.1fx", rotation=90, size="small", padding=1)

    plt.tight_layout()
    fig.savefig(out_prefix.with_suffix(".png"), dpi=300)
    fig.savefig(out_prefix.with_suffix(".svg"))


def plot_runtime(df: pd.DataFrame, title: str, out_prefix: pathlib.Path):
    plot_barplot(df, "resolution", "time", title, out_prefix, write_labels=False)


def plot_memory(df: pd.DataFrame, title: str, out_prefix: pathlib.Path):
    plot_barplot(df, "resolution", "memory", title, out_prefix, write_labels=False)


def compute_runtime_ratio(df: pd.DataFrame, label: str = "time") -> pd.DataFrame:
    # Find the worst tool on average
    baseline_tool = df.groupby("tool")[label].mean().idxmax()

    # Compute mean runtime for each tool and resolution
    tools = []
    resolutions = []
    values = []
    for (tool, resolution), (value) in df.groupby(["tool", "resolution"])[label]:
        tools.append(tool)
        resolutions.append(resolution)
        values.append(value.mean())

    # Compute the baseline for each tool and resolution
    df1 = pd.DataFrame({"tool": tools, "resolution": resolutions, label: values})
    baselines = {}
    for res, df2 in df1.groupby("resolution"):
        baseline = df2.loc[df2["tool"] == baseline_tool, label]
        assert len(baseline) == 1
        baselines[res] = baseline.iloc[0]

    # Compute timing ratios
    for res in df["resolution"].unique():
        value = df1.loc[df1["resolution"] == res, label]
        df1.loc[df1["resolution"] == res, label] = baselines[res] / value

    return df1


def compute_memory_ratio(df: pd.DataFrame, label: str = "memory") -> pd.DataFrame:
    # Find the best tool on average
    baseline_tool = df.groupby("tool")[label].mean().idxmin()

    # Compute mean mem usage for each tool and resolution
    tools = []
    resolutions = []
    values = []
    for (tool, resolution), (value) in df.groupby(["tool", "resolution"])[label]:
        tools.append(tool)
        resolutions.append(resolution)
        values.append(value.mean())

    # Compute the baseline for each tool and resolution
    df1 = pd.DataFrame({"tool": tools, "resolution": resolutions, label: values})
    baselines = {}
    for res, df2 in df1.groupby("resolution"):
        baseline = df2.loc[df2["tool"] == baseline_tool, label]
        assert len(baseline) == 1
        baselines[res] = baseline.iloc[0]

    # Compute timing ratios
    for res in df["resolution"].unique():
        value = df1.loc[df1["resolution"] == res, label]
        df1.loc[df1["resolution"] == res, label] = value / baselines[res]

    return df1


def plot_perf_ratio(df: pd.DataFrame, title: str, out_prefix: pathlib.Path):
    plot_barplot(df, "resolution", "time", title, out_prefix, write_labels=True)


def plot_mem_ratio(df: pd.DataFrame, title: str, out_prefix: pathlib.Path):
    plot_barplot(df, "resolution", "memory", title, out_prefix, write_labels=True)


def main():
    args = vars(make_cli().parse_args())

    df = pd.read_table(args["tsv"])
    df["memory"] /= 1.0e3  # kbs -> MBs

    if args["resolutions"] is not None:
        df = df[df["resolution"].isin(args["resolutions"])]

    df["tool"] = df["tool"] + "_" + df["format"]

    plot_runtime(df, args["title"] + " (runtime)", pathlib.Path(str(args["output_prefix"]) + "_runtime"))
    plot_memory(df, args["title"] + " (memory)", pathlib.Path(str(args["output_prefix"]) + "_memory"))

    df1 = compute_runtime_ratio(df)
    plot_perf_ratio(
        df1,
        args["title"] + " - relative runtime performance",
        pathlib.Path(str(args["output_prefix"]) + "_runtime_ratio"),
    )

    df1 = compute_memory_ratio(df)
    plot_mem_ratio(
        df1, args["title"] + " - relative peak memory usage", pathlib.Path(str(args["output_prefix"]) + "_memory_ratio")
    )


if __name__ == "__main__":
    main()
