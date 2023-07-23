#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.pairs_file, checkIfExists: true).set { pairs }
    Channel.of(params.resolutions).flatten().set { resolutions }
    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    preprocess_pairs(
        pairs
    )

    preprocess_pairs.out.pairs
        .set { pairs_filtered }

    task_ids.combine(pairs_filtered)
        .combine(resolutions)
        .set { tasks }

    hictk_load(
        tasks,
        file(params.chrom_sizes)
    )

    cooler_cload(
        tasks,
        file(params.chrom_sizes)
    )

    summarize(
        hictk_load.out.tsv
            .mix(cooler_cload.out.tsv)
            .map { it[4] }
            .collect()
    )
}

process preprocess_pairs {
    label 'process_medium'

    input:
        path pairs

    output:
        path "*.pairs.zst", emit: pairs

    shell:
        outname="${pairs.simpleName}_filtered.pairs.zst"
        '''
        set -o pipefail

        zcat '!{pairs}' |
        grep -P 'chr[\\dXY]+\\s\\d+\\schr[\\dXY]+\\s' |
        zstd -T'!{task.cpus}' --adapt=min=1,max=8 -o '!{outname}'
        '''
}

process hictk_load {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 1
    memory 36.GB
    label 'process_long'

    tag "${pairs.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(pairs),
              val(resolution)
        path chrom_sizes

    output:
        tuple val(id),
              val("hictk"),
              val("pairs"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${pairs.simpleName}__hictk__pairs__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tpairs\\t!{resolution}\\t' >> '!{outname}'

        mkdir tmp/
        export TMPDIR="$PWD/tmp"

        command time -f '%e\\t%M'             \\
            hictk load '!{chrom_sizes}'       \\
                       '!{resolution}'        \\
                       'out.cool'             \\
                       --format 4dn           \\
                       --assume-unsorted      \\
                       --batch-size 50000000  \\
                       --verbosity=1          \\
                < <(zstdcat '!{pairs}')       \\
                1> /dev/null                  \\
                2>> '!{outname}'
        '''
}

process cooler_cload {
    publishDir "${params.outdir}/cooler/", mode: 'copy'

    cpus 1
    memory 100.GB
    label 'process_very_long'

    tag "${pairs.simpleName}"

    input:
        tuple val(id),
              path(pairs),
              val(resolution)
        path chrom_sizes

    output:
        tuple val(id),
              val("hictk"),
              val("pairs"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${pairs.simpleName}__cooler__pairs__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'cooler\\tpairs\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M'          \\
        cooler cload pairs                 \\
            --chrom1 2                     \\
            --chrom2 4                     \\
            --pos1 3                       \\
            --pos2 5                       \\
            --chunksize 50000000           \\
            '!{chrom_sizes}:!{resolution}' \\
            <(zstdcat '!{pairs}')          \\
            out.cool |&
            grep -v 'INFO' >> '!{outname}'
        '''
}

process summarize {
    publishDir "${params.outdir}/", mode: 'copy'

    input:
        path tsvs

    output:
        path "*.tsv", emit: tsv

    shell:
        outname="report.tsv"
        '''
        summarize_benchmarks.py *.tsv > '!{outname}'
        '''
}
