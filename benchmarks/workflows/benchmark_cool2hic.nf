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

    hictk_convert_mt2(
        tasks
    )
    hictk_convert_mt4(
        tasks
    )
    hictk_convert_mt8(
        tasks
    )
    hictk_convert_mt16(
        tasks
    )

    summarize(
        hictk_convert_mt2.out.tsv
            .mix(hictk_convert_mt4.out.tsv)
            .mix(hictk_convert_mt8.out.tsv)
            .mix(hictk_convert_mt16.out.tsv)
            .map { it[2] }
            .collect()
    )
}


process hictk_convert_mt2 {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 2

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
        outname="${id}__${mcool.simpleName}__hictk_st__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk_mt!{task.cpus}\\tcooler\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'


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

process hictk_convert_mt4 {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 4

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
        outname="${id}__${mcool.simpleName}__hictk_mt${task.cpus}__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk_mt!{task.cpus}\\tcooler\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'


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

process hictk_convert_mt8 {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 8

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
        outname="${id}__${mcool.simpleName}__hictk_mt${task.cpus}__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk_mt!{task.cpus}\\tcooler\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'


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


process hictk_convert_mt16 {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 16

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
        outname="${id}__${mcool.simpleName}__hictk_mt${task.cpus}__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk_mt!{task.cpus}\\tcooler\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'


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
