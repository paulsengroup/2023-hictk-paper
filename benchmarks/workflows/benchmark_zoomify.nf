#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.mcool_file, checkIfExists: true).set { mcools }

    // Pair base resolutions with target resolutions
    Channel.fromList(
        [params.base_resolutions, params.target_resolutions].transpose()
    ).set { resolutions }

    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    task_ids.combine(mcools)
        .combine(resolutions)
        .set { tasks }

    hictk_zoomify(
        tasks
    )

    cooler_coarsen_st(
        tasks
    )

    cooler_coarsen_mt4(
        tasks
    )

    cooler_coarsen_mt8(
        tasks
    )

    summarize(
        hictk_zoomify.out.tsv
            .mix(cooler_coarsen_st.out.tsv)
            .mix(cooler_coarsen_mt4.out.tsv)
            .mix(cooler_coarsen_mt8.out.tsv)
            .map { it[5] }
            .collect()
    )
}


process hictk_zoomify {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 1

    tag "${mcool.fileName}_${resolution1}_${resolution2}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution1),
              val(resolution2)

    output:
        tuple val(id),
              val("hictk"),
              val("cooler"),
              val(resolution1),
              val(resolution2),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${mcool.simpleName}__hictk__pairs__${resolution1}__${resolution2}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tcooler\\t!{resolution2}\\t' >> '!{outname}'

        command time -f '%e\\t%M'                       \\
            hictk zoomify                               \\
                '!{mcool}::/resolutions/!{resolution1}' \\
                out.cool                                \\
                --resolutions '!{resolution2}'          \\
                --verbosity=1                           \\
                --no-copy-base-resolution               \\
                1> /dev/null                            \\
                2>> '!{outname}'
        '''
}

process cooler_coarsen_st {
    publishDir "${params.outdir}/cooler/", mode: 'copy'

    cpus 1
    memory { 8.GB * task.attempt }
    label 'process_very_long'

    tag "${mcool.fileName}_${resolution1}_${resolution2}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution1),
              val(resolution2)

    output:
        tuple val(id),
              val("cooler_st"),
              val("cooler"),
              val(resolution1),
              val(resolution2),
              path("*.tsv"), emit: tsv

    shell:
        factor=resolution2.intdiv(resolution1)
        outname="${id}__${mcool.simpleName}__cooler_st__cooler__${resolution1}__${resolution2}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'cooler_st\\tcooler\\t!{resolution2}\\t' >> '!{outname}'

        command time -f '%e\\t%M'                       \\
            cooler coarsen                              \\
                '!{mcool}::/resolutions/!{resolution1}' \\
                -o out.cool                             \\
                -p '!{task.cpus}'                       \\
                -k '!{factor}'                          |&
                grep -v 'INFO' >> '!{outname}'
        '''
}

process cooler_coarsen_mt4 {
    publishDir "${params.outdir}/cooler/", mode: 'copy'

    cpus 4
    memory { 36.GB * task.attempt }
    label 'process_long'

    tag "${mcool.fileName}_${resolution1}_${resolution2}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution1),
              val(resolution2)

    output:
        tuple val(id),
              val("cooler_mt4"),
              val("cooler"),
              val(resolution1),
              val(resolution2),
              path("*.tsv"), emit: tsv

    shell:
        factor=resolution2.intdiv(resolution1)
        outname="${id}__${mcool.simpleName}__cooler_mt4__cooler__${resolution1}__${resolution2}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'cooler_mt4\\tcooler\\t!{resolution2}\\t' >> '!{outname}'

        command time -f '%e\\t%M'                       \\
            cooler coarsen                              \\
                '!{mcool}::/resolutions/!{resolution1}' \\
                -o out.cool                             \\
                -p '!{task.cpus}'                       \\
                -k '!{factor}'                          |&
                grep -v 'INFO' >> '!{outname}'
        '''
}

process cooler_coarsen_mt8 {
    publishDir "${params.outdir}/cooler/", mode: 'copy'

    cpus 8
    memory { 48.GB * task.attempt }
    label 'process_long'

    tag "${mcool.fileName}_${resolution1}_${resolution2}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution1),
              val(resolution2)

    output:
        tuple val(id),
              val("cooler_mt8"),
              val("cooler"),
              val(resolution1),
              val(resolution2),
              path("*.tsv"), emit: tsv

    shell:
        factor=resolution2.intdiv(resolution1)
        outname="${id}__${mcool.simpleName}__cooler_mt8__cooler__${resolution1}__${resolution2}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'cooler_mt8\\tcooler\\t!{resolution2}\\t' >> '!{outname}'

        command time -f '%e\\t%M'                       \\
            cooler coarsen                              \\
                '!{mcool}::/resolutions/!{resolution1}' \\
                -o out.cool                             \\
                -p '!{task.cpus}'                       \\
                -k '!{factor}'                          |&
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
