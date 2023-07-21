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
        .combine([params.chromosome])
        .set { hic_tasks }

    task_ids.combine(mcool)
        .combine(resolutions)
        .combine([params.chromosome])
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
    straw_sorted_dump(
        hic_tasks
    )
    straw_dump(
        hic_tasks
    )

    summarize(
        hictk_cooler_dump.out.tsv
            .mix(hictk_hic_dump.out.tsv)
            .mix(cooler_dump.out.tsv)
            .mix(straw_sorted_dump.out.tsv)
            .mix(straw_dump.out.tsv)
            .map { it[5] }
            .collect()
    )
}


process hictk_cooler_dump {
    publishDir "${params.outdir}/hictk/cooler", mode: 'copy'

    cpus 1
    memory 16.GB

    tag "${mcool.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution),
              val(chromosome)

    output:
        tuple val(id),
              val("hictk"),
              val("cooler"),
              val(resolution),
              val(chromosome),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${mcool.simpleName}__hictk__cool__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\tcooler\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M' \\
            hictk dump '!{mcool}::/resolutions/!{resolution}' --no-join \\
                --range '!{chromosome}' \\
                1> /dev/null \\
                2>> '!{outname}'
        '''
}

process hictk_hic_dump {
    publishDir "${params.outdir}/hictk/hic", mode: 'copy'

    cpus 1
    memory 16.GB

    tag "${hic.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution),
              val(chromosome)

    output:
        tuple val(id),
              val("hictk"),
              val("hic"),
              val(resolution),
              val(chromosome),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__hictk__hic__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'hictk\\thic\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M' \\
            hictk dump '!{hic}' --resolution '!{resolution}' --no-join \\
                --range '!{chromosome}' \\
                1> /dev/null \\
                2>> '!{outname}'
        '''
}

process cooler_dump {
    publishDir "${params.outdir}/cooler/cooler", mode: 'copy'

    label 'process_long'

    cpus 1
    memory 16.GB

    tag "${mcool.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(mcool),
              val(resolution),
              val(chromosome)

    output:
        tuple val(id),
              val("hictk"),
              val("cooler"),
              val(resolution),
              val(chromosome),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${mcool.simpleName}__cooler__cool__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'cooler\\tcooler\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M' \\
            cooler dump '!{mcool}::/resolutions/!{resolution}' \\
                --range '!{chromosome}' \\
                1> /dev/null \\
                2>> '!{outname}'
        '''
}

process straw_sorted_dump {
    publishDir "${params.outdir}/straw/hic", mode: 'copy'

    label 'process_long'

    cpus 1
    memory 16.GB

    tag "${hic.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution),
              val(chromosome)

    output:
        tuple val(id),
              val("straw_sorted"),
              val("hic"),
              val(resolution),
              val(chromosome),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__straw_sorted__hic__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'straw_sorted\\thic\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M' \\
            straw-sorted observed NONE '!{hic}' '!{chromosome}' '!{chromosome}' BP '!{resolution}' \\
                1> /dev/null \\
                2>> '!{outname}'
        '''
}

process straw_dump {
    publishDir "${params.outdir}/straw/hic", mode: 'copy'

    label 'process_long'

    cpus 1
    memory 16.GB

    tag "${hic.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(hic),
              val(resolution),
              val(chromosome)

    output:
        tuple val(id),
              val("straw"),
              val("hic"),
              val(resolution),
              val(chromosome),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${hic.simpleName}__straw__hic__${resolution}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\ttime\\tmemory\\n' > '!{outname}'
        printf 'straw\\thic\\t!{resolution}\\t' >> '!{outname}'

        command time -f '%e\\t%M' \\
            straw observed NONE '!{hic}' '!{chromosome}' '!{chromosome}' BP '!{resolution}' \\
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
