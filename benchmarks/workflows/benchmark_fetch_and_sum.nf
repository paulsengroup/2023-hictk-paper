#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.hic_file, checkIfExists: true).set { hic }
    Channel.fromPath(params.mcool_file, checkIfExists: true).set { mcool }

    Channel.fromPath(params.domains, checkIfExists: true).set { domains }

    Channel.of(params.resolutions).flatten().set { resolutions }

    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    generate_random_queries(
        domains.combine(["cis", "trans"]),
        params.num_queries
    )

    task_ids.combine(hic)
        .combine(generate_random_queries.out.bedpe)
        .combine(resolutions)
        .set { hic_tasks }

    task_ids.combine(mcool)
        .combine(generate_random_queries.out.bedpe)
        .combine(resolutions)
        .set { cool_tasks }

    fetch_and_sum_hictk_hic(
        hic_tasks
    )
    fetch_and_sum_hictk_cool(
        cool_tasks
    )
    fetch_and_sum_straw(
        hic_tasks
    )
    fetch_and_sum_cooler(
        cool_tasks
    )

    Channel.empty()
        .mix(fetch_and_sum_hictk_cool.out.txt,
             fetch_and_sum_hictk_hic.out.txt,
             fetch_and_sum_cooler.out.txt,
             fetch_and_sum_straw.out.txt)
        .map { it.remove(0); return it }  // drop task id
        // 0: tool
        // 1: format
        // 2: type
        // 3: resolution
        .groupTuple(by: [0, 1, 2, 3],
                    size: params.replicates)
        .set { benchmark_runtime_results }

    Channel.empty()
        .mix(fetch_and_sum_hictk_cool.out.mem,
             fetch_and_sum_hictk_hic.out.mem,
             fetch_and_sum_cooler.out.mem,
             fetch_and_sum_straw.out.mem)
        .map { it.remove(0); return it }  // drop task id
        // 0: tool
        // 1: format
        // 2: type
        // 3: resolution
        .groupTuple(by: [0, 1, 2, 3],
                    size: params.replicates)
        .set { benchmark_memory_results }

    summarize_runtime_replicates(benchmark_runtime_results)
    summarize_memory_replicates(benchmark_memory_results)

           // .branch {
           //    cis:   it[2] == "cis"
           //    trans: it[2] == "trans"
           // }

}


process generate_random_queries {
    publishDir "${params.outdir}/queries/", mode: 'copy'

    label 'process_short'

    input:
        tuple path(domains),
              val(type)

        val num_queries

    output:
        tuple path("*.bedpe.gz"),
              val(type),
              emit: bedpe

    shell:
        outname="${domains.simpleName}_${type}.bedpe.gz"
        '''
        set -o pipefail

        zcat '!{domains}' |
            grep -v '^#' |
            generate_fetch_and_sum_queries.py '!{type}' --num-queries='!{num_queries}' |
            gzip -9 > '!{outname}'
        '''
}

process fetch_and_sum_hictk_cool {
    publishDir "${params.outdir}/hictk/cooler", mode: 'copy'

    cpus 1

    tag "${mcool.fileName}_${resolution}_${type}_${id}"

    input:
        tuple val(id),
              path(mcool),
              path(queries),
              val(type),
              val(resolution)

    output:
        tuple val(id),
              val("hictk"),
              val("cooler"),
              val(type),
              val(resolution),
              path("*.txt"), emit: txt

        tuple val(id),
              val("hictk"),
              val("cooler"),
              val(type),
              val(resolution),
              path("*.mem"), emit: mem

    shell:
        outprefix="${id}__${mcool.simpleName}__hictk__cool__${resolution}__${type}"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tmemory\\n' > '!{outprefix}.mem'
        printf 'hictk\\tcooler\\t!{resolution}\\t' >> '!{outprefix}.mem'

        zcat '!{queries}' |
            command time -f '%M'                                     \\
                         -o '!{outprefix}.mem'                       \\
                         -a                                          \\
                fetch_and_sum '!{mcool}::/resolutions/!{resolution}' \\
                1> '!{outprefix}.txt'
        '''
}

process fetch_and_sum_hictk_hic {
    publishDir "${params.outdir}/hictk/hic", mode: 'copy'

    cpus 1

    tag "${hic.fileName}_${resolution}_${type}_${id}"

    input:
        tuple val(id),
              path(hic),
              path(queries),
              val(type),
              val(resolution)

    output:
        tuple val(id),
              val("hictk"),
              val("hic"),
              val(type),
              val(resolution),
              path("*.txt"), emit: txt

        tuple val(id),
              val("hictk"),
              val("hic"),
              val(type),
              val(resolution),
              path("*.mem"), emit: mem

    shell:
        outprefix="${id}__${hic.simpleName}__hictk__hic__${resolution}__${type}"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tmemory\\n' > '!{outprefix}.mem'
        printf 'hictk\\thic\\t!{resolution}\\t' >> '!{outprefix}.mem'

        zcat '!{queries}' |
            command time -f '%M'                                \\
                         -o '!{outprefix}.mem'                  \\
                         -a                                     \\
            fetch_and_sum '!{hic}' --resolution='!{resolution}' \\
                1> '!{outprefix}.txt'
        '''
}

process fetch_and_sum_cooler {
    publishDir "${params.outdir}/cooler/cooler", mode: 'copy'

    cpus 1

    tag "${mcool.fileName}_${resolution}_${type}_${id}"

    input:
        tuple val(id),
              path(mcool),
              path(queries),
              val(type),
              val(resolution)

    output:
        tuple val(id),
              val("cooler"),
              val("cooler"),
              val(type),
              val(resolution),
              path("*.txt"), emit: txt

        tuple val(id),
              val("cooler"),
              val("cooler"),
              val(type),
              val(resolution),
              path("*.mem"), emit: mem

    shell:
        outprefix="${id}__${mcool.simpleName}__cooler__cooler__${resolution}__${type}"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tmemory\\n' > '!{outprefix}.mem'
        printf 'cooler\\tcooler\\t!{resolution}\\t' >> '!{outprefix}.mem'

        zcat '!{queries}' |
            command time -f '%M'                       \\
                         -o '!{outprefix}.mem'         \\
                         -a                            \\
            fetch_and_sum_cooler.py                    \\
                '!{mcool}::/resolutions/!{resolution}' \\
                1> '!{outprefix}.txt'
        '''
}

process fetch_and_sum_straw {
    publishDir "${params.outdir}/straw/hic", mode: 'copy'

    cpus 1

    tag "${hic.fileName}_${resolution}_${type}_${id}"

    input:
        tuple val(id),
              path(hic),
              path(queries),
              val(type),
              val(resolution)

    output:
        tuple val(id),
              val("straw"),
              val("hic"),
              val(type),
              val(resolution),
              path("*.txt"), emit: txt

        tuple val(id),
              val("straw"),
              val("hic"),
              val(type),
              val(resolution),
              path("*.mem"), emit: mem

    shell:
        outprefix="${id}__${hic.simpleName}__straw__hic__${resolution}__${type}"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tmemory\\n' > '!{outprefix}.mem'
        printf 'straw\\thic\\t!{resolution}\\t' >> '!{outprefix}.mem'

        zcat '!{queries}' |
            command time -f '%M'               \\
                         -o '!{outprefix}.mem' \\
                         -a                    \\
            fetch_and_sum_straw.py             \\
                '!{hic}' '!{resolution}'       \\
                1> '!{outprefix}.txt'          \\
        '''
}

process summarize_runtime_replicates {
    publishDir params.outdir, mode: 'copy',
                              saveAs: { "${tool}/${format}/${resolution}_${type}_runtime.txt" }

    tag "${tool}_${format}_${resolution}_${type}"

    input:
        tuple val(tool),
              val(format),
              val(type),
              val(resolution),
              path(results)

    output:
        tuple val(tool),
              val(format),
              val(type),
              val(resolution),
              path("*.txt"), emit: txt

    shell:
        outname="${resolution}__${tool}__${format}__${type}_runtime.txt"
        '''
        set -o pipefail

        summarize_fetch_and_sum_bench_runtime.py !{results} \\
            --tool='!{tool}' \\
            --format='!{format}' \\
            --resolution='!{resolution}' > '!{outname}'
        '''
}

process summarize_memory_replicates {
    publishDir params.outdir, mode: 'copy',
                              saveAs: { "${tool}/${format}/${resolution}_${type}_memory.txt" }

    tag "${tool}_${format}_${resolution}_${type}"

    input:
        tuple val(tool),
              val(format),
              val(type),
              val(resolution),
              path(results)

    output:
        tuple val(tool),
              val(format),
              val(type),
              val(resolution),
              path("*.txt"), emit: txt

    shell:
        outname="${resolution}__${tool}__${format}__${type}_memory.txt"
        '''
        set -o pipefail

        summarize_fetch_and_sum_bench_memory.py !{results} > '!{outname}'
        '''
}

process plot_runtime {
    publishDir params.outdir, mode: 'copy'

    tag "${type}"

    input:
        tuple val(type),
              path(tsvs)

    output:
        tuple val(type),
              path("*.svg"), emit: svg
        tuple val(type),
              path("*.png"), emit: png

    shell:
        '''
        plot_fetch_and_sum_bench_runtime.py \\
            !{tsvs} \\
            --query-type='!{type}' \\
            --output-prefix '!{type}_runtime'
        '''
}

process plot_memory {
    publishDir params.outdir, mode: 'copy'

    tag "${type}"

    input:
        tuple val(type),
              path(tsvs)

    output:
        tuple val(type),
              path("*.svg"), emit: svg
        tuple val(type),
              path("*.png"), emit: png

    shell:
        '''
        plot_fetch_and_sum_bench_memory.py \\
            !{tsvs} \\
            --query-type='!{type}' \\
            --output-prefix '!{type}_memory'
        '''
}
