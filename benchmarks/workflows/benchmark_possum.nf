#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.mcool_file, checkIfExists: true).set { mcool }
    Channel.fromPath(params.hic_file, checkIfExists: true).set { hic }

    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    task_ids.combine(hic)
        .combine([params.resolution])
        .set { hic_tasks }

    task_ids.combine(mcool)
        .combine([params.resolution])
        .set { cooler_tasks }

    possum_vanilla(
        hic_tasks
    )
    possum_hictk_cooler(
        cooler_tasks
    )
    possum_hictk_hic(
        hic_tasks
    )

    summarize(
        possum_vanilla.out.tsv
            .mix(possum_hictk_cooler.out.tsv)
            .mix(possum_hictk_hic.out.tsv)
            .map { it[4] }
            .collect()
    )
}


process possum_vanilla {
    publishDir "${params.outdir}/straw/hic", mode: 'copy'

    cpus 1

    tag "${hic.fileName}_${resolution}_possum_hic_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution)

    output:
        tuple val(id),
              val("straw"),
              val("hic"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__straw__hic__${resolution}.tsv"
        '''
        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'straw\\thic\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M'    \\
                     -o '!{outname}' \\
                     -a              \\
            POSSUM_power             \\
                -o observed          \\
                '!{hic}'             \\
                out.txt              \\
                '!{resolution}'
        '''
}

process possum_hictk_cooler {
    publishDir "${params.outdir}/hictk/cooler", mode: 'copy'

    cpus 1

    tag "${mcool.fileName}_${resolution}_possum_hictk_cooler_${id}"

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
        outname="${id}__${mcool.simpleName}__hictk__cooler__${resolution}.tsv"
        '''
        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tcooler\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M'                      \\
                     -o '!{outname}'                   \\
                     -a                                \\
            POSSUM_power_hictk                         \\
                -o observed                            \\
                '!{mcool}::/resolutions/!{resolution}' \\
                out.txt                                \\
                '!{resolution}'
        '''
}

process possum_hictk_hic {
    publishDir "${params.outdir}/hictk/hic", mode: 'copy'

    cpus 1

    tag "${hic.fileName}_${resolution}_possum_hictk_hic_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution)

    output:
        tuple val(id),
              val("hictk"),
              val("hic"),
              val(resolution),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__hictk__hic__${resolution}.tsv"
        '''
        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\thic\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M'    \\
                     -o '!{outname}' \\
                     -a              \\
            POSSUM_power_hictk       \\
                -o observed          \\
                '!{hic}'             \\
                out.txt              \\
                '!{resolution}'
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
