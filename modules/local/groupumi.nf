process GROUPUMI {
    tag "$meta.id"
    label 'process_medium'
    
    // Support both Docker and Singularity with the specified image
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://bumproo/umitools' :
        'bumproo/umitools' }"

    input:
    tuple val(meta), path(bam), path(bai)
    path sgrna_annotations

    output:
    tuple val(meta), path("*.groups.tsv"), emit: groups
    tuple val(meta), path("*.groups.annotated.tsv"), emit: annotated
    path "*.group.log", emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def umi_separator = task.ext.umi_separator ?: '_'

    """
    # Set matplotlib config directory to avoid read-only filesystem issues
    export MPLCONFIGDIR=\${PWD}/.matplotlib

    umi_tools group \\
        -I ${bam} \\
        --group-out=${prefix}.groups.tsv \\
        --umi-separator=${umi_separator} \\
        --log=${prefix}.group.log \\
        $args

    annotate_umi_groups.py \\
        -i ${prefix}.groups.tsv \\
        -a ${sgrna_annotations} \\
        -o ${prefix}.groups.annotated.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umi_tools: \$(umi_tools --version 2>&1 | head -n1 | sed 's/.*UMI-tools version: //')
        python: \$(python --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.groups.tsv
    touch ${prefix}.groups.annotated.tsv
    touch ${prefix}.group.log
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umi_tools: \$(umi_tools --version 2>&1 | head -n1 | sed 's/.*UMI-tools version: //')
        python: \$(python --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """
}