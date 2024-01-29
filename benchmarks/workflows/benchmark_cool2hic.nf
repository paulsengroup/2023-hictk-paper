#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.mcool_file, checkIfExists: true).set { mcool }

    Channel.of(params.resolutions).flatten().set { resolutions }
    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    task_ids.combine(mcool)
        .combine(resolutions)
        .set { tasks }

    hictk_convert(
        tasks
    )
    summarize(
        hictk_convert.out.tsv
            .map { it[1] }
    )
}


process hictk_convert_sc {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 1

    tag "${mcool.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution)

    output:
        tuple val(id),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${mcool.simpleName}__hictk__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tcooler\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'


        mkdir tmp/
        command time -f '%e\\t%M'                                \\
                     -o '!{outname}'                             \\
                     -a                                          \\
            hictk convert '!{mcool}::/resolutions/!{resolution}' \\
                          out.hic                                \\
                          --tmpdir tmp/                          \\
                          -t '!{task.cpus}'
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
