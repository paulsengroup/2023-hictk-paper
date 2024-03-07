#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2


workflow {
    Channel.fromPath(params.pairs, checkIfExists: true).set { pairs }
    def chrom_sizes = file(params.chrom_sizes, checkIfExists: true)

    process_chrom_sizes(
        chrom_sizes
    )

    prepare_pairs_for_juicer(
        pairs
    )

    pairs_to_single_res_hic9(
        process_chrom_sizes.out.chrom_sizes,
        prepare_pairs_for_juicer.out.txt.collect(),
        Channel.fromList(params.resolutions)
    )

    pairs_to_hic8(
        process_chrom_sizes.out.chrom_sizes,
        prepare_pairs_for_juicer.out.txt,
        params.resolutions.join(",")
    )

    pairs_to_hic9(
        process_chrom_sizes.out.chrom_sizes,
        prepare_pairs_for_juicer.out.txt,
        params.resolutions.join(",")
    )

    pairs_to_cool(
        pairs,
        process_chrom_sizes.out.chrom_sizes,
        params.resolutions.min(),
        params.assembly
    )

    cooler_zoomify(
        pairs_to_cool.out.cool,
        params.resolutions.join(",")
    )

    hictk_convert(
        Channel.fromPath(params.schistocerca_hic, checkIfExists: true)
    )
}

process process_chrom_sizes {

    input:
        path chrom_sizes

    output:
        path "*.chrom.sizes", emit: chrom_sizes

    shell:
    outname="${chrom_sizes.simpleName}.filtered.chrom.sizes"
    '''
    grep '^chr[XY0-9]\\+[[:space:]]' '!{chrom_sizes}' |
        sort -V > '!{outname}'
    '''
}

process prepare_pairs_for_juicer {
    label 'process_high'

    tag "${pairs.simpleName}"

    input:
        path pairs

    output:
        path "*.txt.gz", emit: txt

    shell:
        outprefix="${pairs.simpleName}"
        '''
        set -o pipefail

        # grep header lines as well as pairs referring to std chromosomes
        zcat '!{pairs}' |
            grep -P '#|chr[\\dXY]+\\s\\d+\\schr[\\dXY]+\\s' |
            4dn_pairs_to_txt |
            pigz -9 -p '!{task.cpus}' > '!{outprefix}.txt.gz'
        '''
}

process pairs_to_hic8 {
    publishDir params.data_dir, mode: 'copy'

    label 'process_medium'
    label 'process_very_long'

    tag "${pairs.simpleName}"

    input:
        path chrom_sizes
        path pairs
        val resolutions

    output:
        path "*.hic8", emit: hic

    shell:
        memory_gb=task.memory.toGiga()
        dest="${pairs.simpleName}.hic8"
        '''
        java -Xmx!{memory_gb}G -Xms!{memory_gb}G -jar "$JUICERTOOLS_JAR" \\
            pre '!{pairs}'             \\
                '!{dest}'              \\
                '!{chrom_sizes}'       \\
                -j !{task.cpus}        \\
                --threads !{task.cpus} \\
                -r '!{resolutions}'    \\
                -n
        '''
}

process pairs_to_hic9 {
    publishDir params.data_dir, mode: 'copy'

    label 'process_medium'
    label 'process_very_long'

    tag "${pairs.simpleName}"

    input:
        path chrom_sizes
        path pairs
        val resolutions

    output:
        path "*.hic9", emit: hic

    shell:
        memory_gb=task.memory.toGiga()
        dest="${pairs.simpleName}.hic9"
        '''
        java -Xmx!{memory_gb}G -Xms!{memory_gb}G -jar "$HICTOOLS_JAR" \\
            pre '!{pairs}'             \\
                '!{dest}'              \\
                '!{chrom_sizes}'       \\
                -j !{task.cpus}        \\
                --threads !{task.cpus} \\
                -r '!{resolutions}'
        '''
}

process pairs_to_cool {
    publishDir params.data_dir, mode: 'copy'

    label 'process_very_long'

    tag "${pairs.simpleName}"

    input:
        path pairs
        path chrom_sizes
        val resolution
        val assembly

    output:
        path "*.cool", emit: cool

    shell:
        memory_gb=task.memory.toGiga()
        dest="${pairs.simpleName}.cool"
        '''
        zcat '!{pairs}' |
        grep -P 'chr[\\dXY]+\\s\\d+\\schr[\\dXY]+\\s' |
        cooler cload pairs \\
            --assembly '!{assembly}' \\
            --chrom1 2 \\
            --chrom2 4 \\
            --pos1 3 \\
            --pos2 5 \\
            '!{chrom_sizes}:!{resolution}' \\
            - \\
            '!{dest}'
        '''
}

process cooler_zoomify {
    publishDir params.data_dir, mode: 'copy'

    label 'process_high'
    label 'process_very_long'

    tag "${cool.simpleName}"

    input:
        path cool
        val resolutions

    output:
        path "*.mcool", emit: mcool

    shell:
        '''
        balance_args=(
            -p !{task.cpus}
            --max-iters 1000
            --tol 0.005
        )

        cooler zoomify          \\
            '!{cool}'           \\
            -p !{task.cpus}     \\
            -r '!{resolutions}' \\
            --balance           \\
            --balance-args="${balance_args[*]}"
        '''
}


process pairs_to_single_res_hic9 {
    publishDir params.data_dir, mode: 'copy'

    label 'process_medium'
    label 'process_very_long'

    tag "${pairs.simpleName}"

    input:
        path chrom_sizes
        path pairs
        val resolution

    output:
        path "*.hic9", emit: hic

    shell:
        memory_gb=task.memory.toGiga()
        dest="${pairs.simpleName}.${resolution}.hic9"
        '''
        java -Xmx!{memory_gb}G -Xms!{memory_gb}G -jar "$HICTOOLS_JAR" \\
            pre '!{pairs}'             \\
                '!{dest}'              \\
                '!{chrom_sizes}'       \\
                -j !{task.cpus}        \\
                --threads !{task.cpus} \\
                -r '!{resolution}'     \\
                -n
        '''
}

process hictk_convert {
    publishDir "${params.data_dir}/input/matrices", mode: 'copy'

    tag "${hic.simpleName}"

    input:
        path hic

    output:
        path "*.mcool", emit: mcool

    shell:
        outname="${hic.simpleName}.mcool"
        '''
        hictk convert '!{hic}' '!{outname}'
        '''
}
