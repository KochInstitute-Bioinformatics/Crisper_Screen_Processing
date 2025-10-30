process ALIGN2LIBRARY {
    tag "$meta.id"
    label 'process_medium'

    // Support both Docker and Singularity with the specified image
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://bumproo/mageck' :
        'bumproo/mageck' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.sorted.bam"),     emit: bam
    tuple val(meta), path("*.sorted.bam.bai"), emit: bai
    path "versions.yml",                       emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def bowtie2_index = task.ext.bowtie2_index ?: '/net/bmc-lab3/data/bcc/projects/tfal23-Knouse/251009Kno-crispr/sgRNA_library/knouse.shortened.71548'
    def trim_3prime = task.ext.trim_3prime ?: '31'
    
    """
    # Bowtie2 alignment with filtering and BAM conversion
    bowtie2 \\
        -x $bowtie2_index \\
        -U $reads \\
        -3 $trim_3prime \\
        --no-unal \\
        $args \\
        | egrep '^@SQ|^@PG|MD:Z:19' \\
        | samtools view -bS - > ${prefix}.bam

    # Sort the BAM file
    samtools sort -o ${prefix}.sorted.bam ${prefix}.bam

    # Index the sorted BAM file
    samtools index ${prefix}.sorted.bam

    # Clean up intermediate BAM file
    rm ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$(echo \$(bowtie2 --version 2>&1) | sed 's/.*bowtie2-align-s version //; s/ .*\$//')
        samtools: \$(samtools --version 2>&1 | head -n1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.sorted.bam
    touch ${prefix}.sorted.bam.bai

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$(echo \$(bowtie2 --version 2>&1) | sed 's/.*bowtie2-align-s version //; s/ .*\$//')
        samtools: \$(samtools --version 2>&1 | head -n1 | sed 's/samtools //')
    END_VERSIONS
    """
}