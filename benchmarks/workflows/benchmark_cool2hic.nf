#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.mcool_file, checkIfExists: true).set { mcool }

    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    task_ids.combine(mcool)
        .set { tasks }

    hictk_convert(
        tasks
    )
    summarize(
        hictk_convert.out.tsv
            .map { it[1] }
    )
}


process hictk_convert {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 8

    tag "${mcool.fileName}_${id}"

    input:
        tuple val(id),
              path(mcool)

    output:
        tuple val(id),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${mcool.simpleName}__hictk.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tcooler\\tall\\t' >> '!{outname}'


        mkdir tmp/
        command time -f '%e\\t%M'                            \\
            hictk convert '!{mcool}'                         \\
                          out.hic                            \\
                          --tmpdir tmp/                      \\
                          --juicer-tools-jar "$HICTOOLS_JAR" \\
                          -p '!{task.cpus}'                  \\
                          --verbosity=1                      \\
                    1> /dev/null                             \\
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
