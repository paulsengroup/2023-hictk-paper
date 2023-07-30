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

    hicrep_vanilla(
        cooler_tasks
    )
    hicrep_hictk_cooler(
        cooler_tasks
    )
    hicrep_hictk_hic(
        hic_tasks
    )

    summarize(
        //hicrep_vanilla.out.tsv
        Channel.empty()
            .mix(hicrep_hictk_cooler.out.tsv)
            .mix(hicrep_hictk_hic.out.tsv)
            .map { it[4] }
            .collect()
    )
}


process hicrep_vanilla {
    publishDir "${params.outdir}/straw/hic", mode: 'copy'

    cpus 1

    tag "${mcool.fileName}_${resolution}_hicrep_hic_${id}"

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
        outname="${id}__${mcool.simpleName}__straw__hic__${resolution}.tsv"
        '''
        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'cooler\\tcooler\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M'      \\
                     -o '!{outname}'   \\
                     -a                \\
            hicrep                     \\
                '!{mcool}' '!{mcool}'  \\
                out.txt                \\
                --h 10                 \\
                --dBPMax 5000000       \\
                --binSize '!{resolution}'
        '''
}

process hicrep_hictk_cooler {
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

        command time -f '%e\\t%M'      \\
                     -o '!{outname}'   \\
                     -a                \\
            hicrep_hictkpy             \\
                '!{mcool}' '!{mcool}'  \\
                out.txt                \\
                --h 10                 \\
                --dBPMax 5000000       \\
                --binSize '!{resolution}'
        '''
}

process hicrep_hictk_hic {
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
        command time -f '%e\\t%M'      \\
                     -o '!{outname}'   \\
                     -a                \\
            hicrep_hictkpy             \\
                '!{hic}' '!{hic}'      \\
                out.txt                \\
                --h 10                 \\
                --dBPMax 5000000       \\
                --binSize '!{resolution}'
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
