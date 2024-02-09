#!/usr/bin/env nextflow
// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

nextflow.enable.dsl=2

workflow {
    Channel.fromPath(params.pairs_file, checkIfExists: true).set { pairs }
    Channel.of(params.resolutions).flatten().set { resolutions }
    Channel.of(params.cpu_cores).flatten().set { cpus }
    task_ids = Channel.of((1..params.replicates).toList()).flatten()

    preprocess_pairs_zst(
        pairs
    )

    preprocess_pairs_gz(
        pairs
    )

    preprocess_pairs_zst.out.pairs
        .set { pairs_filtered_zst }
    preprocess_pairs_gz.out.pairs
        .set { pairs_filtered_gz }

    task_ids.combine(pairs_filtered_zst)
        .combine(resolutions)
        .set { tasks_cooler }

    task_ids.combine(pairs_filtered_zst)
        .combine(resolutions)
        .set { tasks_hictk_cool }

    task_ids.combine(pairs_filtered_zst)
        .combine(resolutions)
        .combine(cpus)
        .set { tasks_hictk_hic }

    task_ids.combine(pairs_filtered_gz)
        .combine(resolutions)
        .combine(cpus)
        .set { tasks_hictools }

    hictk_load_cool(
        tasks_hictk_cool,
        file(params.chrom_sizes)
    )

    hictk_load_hic(
        tasks_hictk_hic,
        file(params.chrom_sizes)
    )

    cooler_cload(
        tasks_cooler,
        file(params.chrom_sizes)
    )

    hictools_pre(
        tasks_hictools,
        file(params.chrom_sizes)
    )

    summarize(
        hictk_load_cool.out.tsv
            .mix(hictk_load_hic.out.tsv)
            .mix(cooler_cload.out.tsv)
            .mix(hictools_pre.out.tsv)
            .map { it[5] }
            .collect()
    )
}

process preprocess_pairs_zst {
    label 'process_high'

    input:
        path pairs

    output:
        path "*.pairs.zst", emit: pairs

    shell:
        outname="${pairs.simpleName}_filtered.pairs.zst"
        '''
        set -o pipefail

        cat > header.txt <<- EOM
        ## pairs format v1.0
        #sorted: chr1-chr2-pos1-pos2
        #shape: upper triangle
        #columns: readID chr1 pos1 chr2 pos2 strand1 strand2
        EOM

        cat header.txt | zstd -19 > '!{outname}'

        zcat '!{pairs}' |
        grep -P 'chr[\\dXY]+\\s\\d+\\schr[\\dXY]+\\s' |
        zstd -T'!{task.cpus}' -19 >> '!{outname}'
        '''
}

process preprocess_pairs_gz {
    label 'process_high'

    input:
        path pairs

    output:
        path "*.pairs.gz", emit: pairs

    shell:
        outname="${pairs.simpleName}_filtered.pairs.gz"
        '''
        set -o pipefail

        cat > header.txt <<- EOM
        ## pairs format v1.0
        #sorted: chr1-chr2-pos1-pos2
        #shape: upper triangle
        #columns: readID chr1 pos1 chr2 pos2 strand1 strand2
        EOM

        cat header.txt | pigz -9 > '!{outname}'

        zcat '!{pairs}' |
        grep -P 'chr[\\dXY]+\\s\\d+\\schr[\\dXY]+\\s' |
        pigz -p '!{task.cpus}' -9 >> '!{outname}'
        '''
}

process hictk_load_cool {
    publishDir "${params.outdir}/hictk/cool", mode: 'copy'

    cpus 1
    memory 36.GB
    label 'process_long'

    tag "${pairs.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(pairs),
              val(resolution)
        path chrom_sizes

    output:
        tuple val(id),
              val("hictk"),
              val("cooler"),
              val(resolution),
              val(task.cpus),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${pairs.simpleName}__hictk__cool__${resolution}__${task.cpus}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\tsize\\n' > '!{outname}'
        printf 'hictk\\tcool\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'

        mkdir tmp/
        export TMPDIR="$PWD/tmp"

        command time -f '%e\\t%M'             \\
                     -o '!{outname}'          \\
                     -a                       \\
            hictk load '!{chrom_sizes}'       \\
                       '!{resolution}'        \\
                       'out.cool'             \\
                       --format 4dn           \\
                       --assume-unsorted      \\
                       --batch-size 50000000  \\
                       --verbosity=1          \\
                < <(zstdcat '!{pairs}')

        truncate -s -1 '!{outname}'  # Remove newline

        printf '\\t%d\\n' "$(du -b out.cool | cut -f 1)" >> '!{outname}'
        '''
}

process hictk_load_hic {
    publishDir "${params.outdir}/hictk/hic", mode: 'copy'

    cpus 1
    memory 36.GB
    label 'process_long'

    tag "${pairs.fileName}_${resolution}_${id}"

    input:
        tuple val(id),
              path(pairs),
              val(resolution),
              val(cpus)
        path chrom_sizes

    output:
        tuple val(id),
              val("hictk"),
              val("hic"),
              val(resolution),
              val(cpus),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${pairs.simpleName}__hictk__hic__${resolution}__${cpus}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\tsize\\n' > '!{outname}'
        printf 'hictk\\thic\\t!{resolution}\\t!{cpus}\\t' >> '!{outname}'

        mkdir tmp/
        export TMPDIR="$PWD/tmp"

        command time -f '%e\\t%M'             \\
                     -o '!{outname}'          \\
                     -a                       \\
            hictk load '!{chrom_sizes}'       \\
                       '!{resolution}'        \\
                       'out.hic'              \\
                       --format 4dn           \\
                       --assume-unsorted      \\
                       --batch-size 50000000  \\
                       --verbosity=1          \\
                < <(zstdcat '!{pairs}')

        truncate -s -1 '!{outname}'  # Remove newline

        printf '\\t%d\\n' "$(du -b out.hic | cut -f 1)" >> '!{outname}'
        '''
}


process cooler_cload {
    publishDir "${params.outdir}/cooler/", mode: 'copy'

    cpus 1
    memory 100.GB
    label 'process_very_long'

    tag "${pairs.simpleName}"

    input:
        tuple val(id),
              path(pairs),
              val(resolution)
        path chrom_sizes

    output:
        tuple val(id),
              val("hictk"),
              val("cooler"),
              val(resolution),
              val(task.cpus),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${pairs.simpleName}__cooler__cooler__${resolution}__${task.cpus}.tsv"
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\tsize\\n' > '!{outname}'
        printf 'cooler\\tcool\\t!{resolution}\\t!{task.cpus}\\t' >> '!{outname}'

        command time -f '%e\\t%M'          \\
                     -o '!{outname}'       \\
                     -a                    \\
        cooler cload pairs                 \\
            --chrom1 2                     \\
            --chrom2 4                     \\
            --pos1 3                       \\
            --pos2 5                       \\
            --chunksize 50000000           \\
            '!{chrom_sizes}:!{resolution}' \\
            <(zstdcat '!{pairs}')          \\
            out.cool

        truncate -s -1 '!{outname}'  # Remove newline

        printf '\\t%d\\n' "$(du -b out.cool | cut -f 1)" >> '!{outname}'
        '''
}


process hictools_pre {
    publishDir "${params.outdir}/hictools/", mode: 'copy'

    memory 650.GB
    label 'process_very_long'

    tag "${pairs.simpleName}"

    input:
        tuple val(id),
              path(pairs),
              val(resolution),
              val(cpus)
        path chrom_sizes

    output:
        tuple val(id),
              val("hictools"),
              val("hic"),
              val(resolution),
              val(cpus),
              path("*.tsv"), emit: tsv

    shell:
        outname="${id}__${pairs.simpleName}__hictools__hic__${resolution}__${cpus}.tsv"
        memory_gb=task.memory.toGiga()
        '''
        set -o pipefail

        printf 'tool\\tformat\\tresolution\\tcpus\\ttime\\tmemory\\tsize\\n' > '!{outname}'
        printf 'hictools\\thic\\t!{resolution}\\t!{cpus}\\t' >> '!{outname}'

        mkdir tmp/
        export TMPDIR="$PWD/tmp"

        command time -f '%e\\t%M'          \\
                     -o '!{outname}'       \\
                     -a                    \\
            run_hic_tools_pre.sh \\
                '!{pairs}' \\
                out.hic \\
                "$TMPDIR" \\
                "$HICTOOLS_JAR" \\
                '!{resolution}' \\
                '!{cpus}' \\
                !{memory_gb}G

        java -jar -Xmx

        truncate -s -1 '!{outname}'  # Remove newline

        printf '\\t%d\\n' "$(du -b out.hic | cut -f 1)" >> '!{outname}'
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
