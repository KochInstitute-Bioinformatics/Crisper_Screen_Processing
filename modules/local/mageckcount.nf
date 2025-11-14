process MAGECKCOUNT {
    tag "mageck_count"
    label 'process_medium'
    
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://bumproo/mageck' :
        'bumproo/mageck' }"
    
    publishDir "${params.outdir}/mageck", mode: 'copy'
    
    input:
    path ordered_bam_list  // This will be a file containing ordered BAM paths
    path library_file
    val sample_labels
    val output_prefix
    
    output:
    path "${output_prefix}.count.txt", emit: counts
    path "${output_prefix}.countsummary.txt", emit: summary
    path "${output_prefix}.count_normalized.txt", emit: normalized, optional: true
    path "versions.yml", emit: versions
    
    when:
    task.ext.when == null || task.ext.when
    
    script:
    def args = task.ext.args ?: ''
    def norm_method = task.ext.norm_method ?: 'median'
    
    // Create comma-separated sample labels
    def sample_label_str = sample_labels instanceof List ? sample_labels.join(',') : sample_labels
    
    """
    # Read the ordered BAM file list
    BAM_FILES=\$(cat ${ordered_bam_list} | tr '\\n' ' ')
    
    echo "Sample labels: ${sample_label_str}"
    echo "BAM files in order: \$BAM_FILES"
    
    mageck count \\
        -l ${library_file} \\
        -n ${output_prefix} \\
        --norm-method ${norm_method} \\
        --sample-label ${sample_label_str} \\
        --fastq \\
        \$BAM_FILES \\
        ${args}
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mageck: \$(mageck --version 2>&1 | head -n1 | sed 's/.*MAGeCK //' | sed 's/ .*//')
    END_VERSIONS
    """
    
    stub:
    """
    touch ${output_prefix}.count.txt
    touch ${output_prefix}.countsummary.txt
    touch ${output_prefix}.count_normalized.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mageck: \$(mageck --version 2>&1 | head -n1 | sed 's/.*MAGeCK //' | sed 's/ .*//')
    END_VERSIONS
    """
}