# Synopsis

This repository contains the source code and input data used for the benchmarks for: hictk: blazing fast toolkit to work with .hic and .cool files (preprint available soon).  <!-- TODO: reference paper -->

Input data download, subsequent analyses and benchmarks are automated using Nextflow and Singularity/Apptainer.

## Docker images availability

Docker images are hosted on GHCR and can be found in the [Packages](https://github.com/orgs/paulsengroup/packages?repo_name=2023-hictk-paper) page of this repository.

Images were generated using the `build*dockerfile.yml` GHA workflows using the Dockerfiles from the `containers` folder.

## Nextflow workflows

Nextflow workflows under `preprocessing/workflows` and `benchmarks/workflows` were developed and tested using Nextflow v23.04.1, and should in principle work with any version supporting Nextflow DSL2.

Each workflow is paired with a config file (see `preprocessing/configs` and `benchmarks/configs` folders). As an example, `preprocessing/workflows/fetch_data.nf` is paired with config `preprocessing/configs/fetch_data.config`.

## Requirements

- Access to an internet connection (required to download input files and Docker images)
- Nextflow v20.07.1 or newer
- Apptainer/Singularity (tested with Apptainer v1.2.2)

## Running workflows

Please make sure Nextflow is properly installed and configured before running any of the workflows.

The following workflows should be executed first, as they download and prepare files required by other workflows.
1. `fetch_data.nf`
2. `preprocess_data.nf`

The `fetch_data.nf` workflow requires internet access and can fail for various reason (e.g. connection reset by peer, service temporarily unavailable etc.). In case the workflow fails, wait few minutes, then relaunch the workflow.

```bash
cd preprocessing/

./run_fetch_data.sh
./run_preprocess_data.sh
```

The rest of the workflows can be run in any order:

```bash
cd benchmarks/

run_benchmark_cool2hic.sh
run_benchmark_dump_chrom.sh
run_benchmark_dump_gw.sh
run_benchmark_fetch_and_sum.sh
run_benchmark_hic2ool.sh
run_benchmark_hicrep.sh
run_benchmark_load.sh
run_benchmark_workflow.sh
run_benchmark_zoomify.sh
```

Inside the `common/configs` folder there are the following base configs:
- `base_hovig.config`
- `base_linux.config`
- `base_saga.config`
- `base_macos.config`

These configs are passed to all workflows, and define available computation resources.
You will most likely have to update one of the configs with resources available on our machine/cluster.

Feel free to use `base_saga.config` as starting point for a config to run benchmarks on an HPC cluster.

In order to avoid IO bottlenecks when running benchmarks for hictk's paper, input files used in benchmarks were stored on a ram-disk under /dev/shm/.
In order to run benchmarks you have two options:

Create folder `/dev/shm/2023-hictk-paper/` and copy the following files inside that folder:
- ENCFF301CUL_cis.bedpe.gz
- ENCFF301CUL_trans.bedpe.gz
- ENCFF447ERX.hic8
- ENCFF447ERX.hic9
- ENCFF447ERX.mcool

Edit the config files and update variables `hic_file`, `hic8_file`, `hic9_file` and `mcool_file` to point to files stored under `data/` (these files are created by the preprocessing workflows).

Example:
```
hic8_file = "${data_dir}/ENCFF447ERX.hic8"
hic9_file = "${data_dir}/ENCFF447ERX.hic9"
hic_file = "${data_dir}/ENCFF447ERX.hic9"
mcool_file = "${data_dir}/ENCFF447ERX.mcool"
```
