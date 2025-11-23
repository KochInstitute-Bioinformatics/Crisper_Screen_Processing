process GENERATE_SUMMARY {
    tag "summary"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.11' :
        'quay.io/biocontainers/python:3.11' }"

    input:
    path samples_csv
    path fastqc_zips
    path fastqc_umi_zips
    
    output:
    path "summary.csv", emit: summary
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Create directories for FastQC outputs
    mkdir -p fastqc_raw
    mkdir -p fastqc_umi
    
    # Copy all raw FastQC zip files
    if [ -n "${fastqc_zips}" ]; then
        cp ${fastqc_zips} fastqc_raw/ 2>/dev/null || true
    fi
    
    # Copy all UMI FastQC zip files
    if [ -n "${fastqc_umi_zips}" ]; then
        cp ${fastqc_umi_zips} fastqc_umi/ 2>/dev/null || true
    fi
    
    # Generate summary
    generate_summary.py ${samples_csv} fastqc_raw fastqc_umi summary.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch summary.csv
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
