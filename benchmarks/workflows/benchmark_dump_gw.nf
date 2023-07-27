#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.hic_file, checkIfExists: true).set { hic }
    Channel.fromPath(params.mcool_file, checkIfExists: true).set { mcool }

    Channel.of(params.resolutions).flatten().set { resolutions }

    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    task_ids.combine(hic)
        .combine(resolutions)
        .set { hic_tasks }

    task_ids.combine(mcool)
        .combine(resolutions)
        .set { cool_tasks }

    hictk_cooler_dump(
        cool_tasks
    )
    hictk_hic_dump(
        hic_tasks
    )
    cooler_dump(
        cool_tasks
    )

    summarize(
        hictk_cooler_dump.out.tsv
            .mix(hictk_hic_dump.out.tsv)
            .mix(cooler_dump.out.tsv)
            .map { it[4] }
            .collect()
    )
}


process hictk_cooler_dump {
    publishDir "${params.outdir}/hictk/cooler", mode: 'copy'

    cpus 1

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

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tcooler\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M' \\
            hictk dump '!{mcool}::/resolutions/!{resolution}' --no-join \\
                1> /dev/null \\
                2>> '!{outname}'
        '''
}

process hictk_hic_dump {
    publishDir "${params.outdir}/hictk/hic", mode: 'copy'

    cpus 1

    tag "${hic.fileName}_${resolution}_${id}"

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
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\thic\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M' \\
            hictk dump '!{hic}' --resolution '!{resolution}' --no-join \\
                1> /dev/null \\
                2>> '!{outname}'
        '''
}

process cooler_dump {
    publishDir "${params.outdir}/cooler/cooler", mode: 'copy'

    label 'process_long'

    cpus 1

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
        outname="${id}__${mcool.simpleName}__cooler__cool__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'cooler\\tcooler\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M' \\
            cooler dump '!{mcool}::/resolutions/!{resolution}' \\
                1> /dev/null \\
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
