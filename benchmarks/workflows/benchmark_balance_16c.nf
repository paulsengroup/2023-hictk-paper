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

    hictk_balance(
        tasks
    )
    cooler_balance(
        tasks
    )

    summarize(
        hictk_balance.out.tsv
            .mix(cooler_balance.out.tsv)
            .map { it[4] }
            .collect()
    )
}


process hictk_balance {
    publishDir "${params.outdir}/hictk/cooler", mode: 'copy'

    cpus 16

    tag "${mcool.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution)

    output:
        tuple val(id),
              val("hictk"),
              val("cooler"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${mcool.simpleName}__hictk__cool__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tcooler\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'

        mkdir tmp/
        export TMPDIR=tmp/

        command time -f '%e\\t%M'                                          \\
                     -o '!{outname}'                                       \\
                     -a                                                    \\
            hictk balance '!{mcool}::/resolutions/!{resolution}'           \\
                -t '!{task.cpus}'                                          \\
                --max-iters 50                                             \\
                --stdout                                                   \\
                1> /dev/null
        '''
}


process cooler_balance {
    publishDir "${params.outdir}/cooler/cooler", mode: 'copy'

    cpus 16

    tag "${mcool.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution)

    output:
        tuple val(id),
              val("cooler"),
              val("cooler"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${mcool.simpleName}__cooler__cool__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\n' > '!{outname}'
        printf 'cooler\\tcooler\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'

        cp '!{mcool}' matrix.mcool
        chmod 600 matrix.mcool

        command time -f '%e\\t%M'                                          \\
                     -o '!{outname}'                                       \\
                     -a                                                    \\
            cooler balance 'matrix.mcool::/resolutions/!{resolution}'      \\
                -p '!{task.cpus}'                                          \\
                --max-iters 50                                             \\
                --stdout                                                   \\
                1> /dev/null
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
