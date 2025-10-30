process UMI2DEFLINE {
    tag "$meta.id"
    label 'process_medium'

    // Support both Docker and Singularity with the specified image
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://bumproo/umitools' :
        'bumproo/umitools' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_with_umi.fastq.gz"), emit: reads
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def bc_pattern = task.ext.bc_pattern ?: '(?P<umi_1>.{11})CAAAAAA.*'
    
    """
    # UMI extraction from Read2, output processed Read1 with UMI in defline
    umi_tools extract \\
        --bc-pattern='$bc_pattern' \\
        --extract-method=regex \\
        -I ${reads[1]} \\
        --read2-in=${reads[0]} \\
        -S /dev/null \\
        --read2-out=${prefix}_with_umi.fastq \\
        --log=${prefix}_extract.log \\
        $args

    # Compress the output
    gzip ${prefix}_with_umi.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umi_tools: \$(umi_tools --version 2>&1 | head -n1 | sed 's/.*UMI-tools version: //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_with_umi.fastq.gz
    touch ${prefix}_extract.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umi_tools: \$(umi_tools --version 2>&1 | head -n1 | sed 's/.*UMI-tools version: //')
    END_VERSIONS
    """
}
