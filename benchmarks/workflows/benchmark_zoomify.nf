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

    task_ids.combine([params.hic_file_pattern])
        .combine(resolutions)
        .map {
            it[1] = file(it[1].replaceFirst(/__xxx__/, it[2].toString()), checkIfExists: true)
            it
        }
        .set { tasks_hic }

    task_ids.combine(mcools)
        .combine(resolutions)
        .set { tasks_cool }


    hictk_zoomify_hic_st(
        tasks_hic
    )

    hictk_zoomify_hic_mt4(
        tasks_hic
    )

    hictk_zoomify_hic_mt8(
        tasks_hic
    )

    hictk_zoomify_cool(
        tasks_cool
    )

    cooler_coarsen_st(
        tasks_cool
    )

    cooler_coarsen_mt4(
        tasks_cool
    )

    cooler_coarsen_mt8(
        tasks_cool
    )

    summarize(
        hictk_zoomify_cool.out.tsv
            .mix(cooler_coarsen_st.out.tsv)
            .mix(cooler_coarsen_mt4.out.tsv)
            .mix(cooler_coarsen_mt8.out.tsv)
            .mix(hictk_zoomify_hic_st.out.tsv)
            .mix(hictk_zoomify_hic_mt4.out.tsv)
            .mix(hictk_zoomify_hic_mt8.out.tsv)
            .map { it[5] }
            .collect()
    )
}


process hictk_zoomify_cool {
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
        outname="${id}__${mcool.simpleName}__hictk__cool__${resolution1}__${resolution2}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tcooler\\t!{resolution2}\\t' >> '!{outname}'

        command time -f '%e\\t%M'                       \\
                     -o '!{outname}'                    \\
                     -a                                 \\
            hictk zoomify                               \\
                '!{mcool}::/resolutions/!{resolution1}' \\
                out.cool                                \\
                --resolutions '!{resolution2}'          \\
                --verbosity=1                           \\
                --no-copy-base-resolution
        '''
}

process hictk_zoomify_hic_st {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 1

    tag "${hic.fileName}_${resolution1}_${resolution2}_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution1),
              val(resolution2)

    output:
        tuple val(id),
              val("hictk"),
              val("hic"),
              val(resolution1),
              val(resolution2),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__hictk_st__hic__${resolution1}__${resolution2}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk_st\\thic\\t!{resolution2}\\t' >> '!{outname}'

        mkdir tmp
        export TMPDIR="$PWD/tmp"

        command time -f '%e\\t%M'                       \\
                     -o '!{outname}'                    \\
                     -a                                 \\
            hictk zoomify                               \\
                '!{hic}'                                \\
                out.hic                                 \\
                --resolutions '!{resolution2}'          \\
                --verbosity=1                           \\
                --skip-all-vs-all                       \\
                --no-copy-base-resolution
        '''
}

process hictk_zoomify_hic_mt4 {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 4

    tag "${hic.fileName}_${resolution1}_${resolution2}_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution1),
              val(resolution2)

    output:
        tuple val(id),
              val("hictk"),
              val("hic"),
              val(resolution1),
              val(resolution2),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__hictk_mt4__hic__${resolution1}__${resolution2}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk_mt4\\thic\\t!{resolution2}\\t' >> '!{outname}'

        mkdir tmp
        export TMPDIR="$PWD/tmp"

        command time -f '%e\\t%M'                       \\
                     -o '!{outname}'                    \\
                     -a                                 \\
            hictk zoomify                               \\
                '!{hic}'                                \\
                out.hic                                 \\
                --threads '!{task.cpus}'                \\
                --resolutions '!{resolution2}'          \\
                --verbosity=1                           \\
                --skip-all-vs-all                       \\
                --no-copy-base-resolution
        '''
}


process hictk_zoomify_hic_mt8 {
    publishDir "${params.outdir}/hictk/", mode: 'copy'

    cpus 8

    tag "${hic.fileName}_${resolution1}_${resolution2}_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution1),
              val(resolution2)

    output:
        tuple val(id),
              val("hictk"),
              val("hic"),
              val(resolution1),
              val(resolution2),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__hictk_mt8__hic__${resolution1}__${resolution2}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk_mt8\\thic\\t!{resolution2}\\t' >> '!{outname}'

        mkdir tmp
        export TMPDIR="$PWD/tmp"

        command time -f '%e\\t%M'                       \\
                     -o '!{outname}'                    \\
                     -a                                 \\
            hictk zoomify                               \\
                '!{hic}'                                \\
                out.hic                                 \\
                --threads '!{task.cpus}'                \\
                --resolutions '!{resolution2}'          \\
                --verbosity=1                           \\
                --skip-all-vs-all                       \\
                --no-copy-base-resolution
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
                     -o '!{outname}'                    \\
                     -a                                 \\
            cooler coarsen                              \\
                '!{mcool}::/resolutions/!{resolution1}' \\
                -o out.cool                             \\
                -p '!{task.cpus}'                       \\
                -k '!{factor}'
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
                     -o '!{outname}'                    \\
                     -a                                 \\
            cooler coarsen                              \\
                '!{mcool}::/resolutions/!{resolution1}' \\
                -o out.cool                             \\
                -p '!{task.cpus}'                       \\
                -k '!{factor}'
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
                     -o '!{outname}'                    \\
                     -a                                 \\
            cooler coarsen                              \\
                '!{mcool}::/resolutions/!{resolution1}' \\
                -o out.cool                             \\
                -p '!{task.cpus}'                       \\
                -k '!{factor}'
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
