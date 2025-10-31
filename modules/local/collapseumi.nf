process COLLAPSEUMI {
    tag "$meta.id"
    label 'process_medium'

    // Support both Docker and Singularity with the specified image
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://bumproo/umitools' :
        'bumproo/umitools' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*_deduplicated.bam"), emit: bam
    path "*_dedup.log",                          emit: log
    path "versions.yml",                         emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def umi_separator = task.ext.umi_separator ?: '_'
    def extract_method = task.ext.extract_method ?: 'read_id'
    
    """
    # UMI deduplication using umi_tools
    umi_tools dedup \\
        --extract-umi-method=$extract_method \\
        --umi-separator=$umi_separator \\
        -I $bam \\
        -S ${prefix}_deduplicated.bam \\
        --log=${prefix}_dedup.log \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umi_tools: \$(umi_tools --version 2>&1 | head -n1 | sed 's/.*UMI-tools version: //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_deduplicated.bam
    touch ${prefix}_dedup.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umi_tools: \$(umi_tools --version 2>&1 | head -n1 | sed 's/.*UMI-tools version: //')
    END_VERSIONS
    """
}