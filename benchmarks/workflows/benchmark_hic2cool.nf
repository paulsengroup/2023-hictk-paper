#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.hic8_file, checkIfExists: true).set { hic8 }
    Channel.fromPath(params.hic9_file, checkIfExists: true).set { hic9 }

    Channel.of(params.resolutions).flatten().set { resolutions }

    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    task_ids.combine(hic8)
        .combine(resolutions)
        .set { hic8_tasks }

    task_ids.combine(hic9)
        .combine(resolutions)
        .set { hic9_tasks }

    hictk_convert8(
        hic8_tasks
    )
    hictk_convert9(
        hic9_tasks
    )
    hic2cool(
        hic8_tasks
    )

    summarize(
        hictk_convert8.out.tsv
            .mix(hictk_convert9.out.tsv)
            .mix(hic2cool.out.tsv)
            .map { it[5] }
            .collect()
    )
}


process hictk_convert8 {
    publishDir "${params.outdir}/hictk/hic8", mode: 'copy'

    cpus 2

    tag "${hic.fileName}_${resolution}_v8_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution)

    output:
        tuple val(id),
              val("hictk"),
              val("hic8"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__hictk__hic8__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\thic8\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M'             \\
            hictk convert '!{hic}'            \\
                'out.cool'                    \\
                --verbosity=1                 \\
                --resolutions '!{resolution}' \\
                1> /dev/null                  \\
                2>> '!{outname}'
        '''
}

process hictk_convert9 {
    publishDir "${params.outdir}/hictk/hic9", mode: 'copy'

    cpus 2

    tag "${hic.fileName}_${resolution}_v9_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution)

    output:
        tuple val(id),
              val("hictk"),
              val("hic9"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__hictk__hic9__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\thic9\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M'             \\
            hictk convert '!{hic}'            \\
                'out.cool'                    \\
                --verbosity=1                 \\
                --resolutions '!{resolution}' \\
                1> /dev/null                  \\
                2>> '!{outname}'
        '''
}

process hic2cool {
    publishDir "${params.outdir}/hi2cool/hic8", mode: 'copy'

    label 'process_very_long'

    cpus 2
    memory 32.GB

    tag "${hic.fileName}_${resolution}_v8_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution)

    output:
        tuple val(id),
              val("hic2cool"),
              val("hic8"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__hic2cool__hic8__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hic2cool\\thic8\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M'             \\
            hic2cool convert                  \\
                '!{hic}'                      \\
                'out.cool'                    \\
                --resolution '!{resolution}'  \\
                -s                            \\
                -p '!{task.cpus}'             |&
                grep -vF '###'                |&
                grep -vF 'WARNING'            \\
                2>> '!{outname}'
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
