process GENERATE_SUMMARY {
    tag "summary"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.11' :
        'quay.io/biocontainers/python:3.11' }"

    input:
    path samples_csv
    path fastqc_zips
    
    output:
    path "summary.csv", emit: summary
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Create a directory for FastQC outputs
    mkdir -p fastqc_data
    
    # Copy all FastQC zip files to the directory
    if [ -n "${fastqc_zips}" ]; then
        cp ${fastqc_zips} fastqc_data/ 2>/dev/null || true
    fi
    
    # Generate summary
    generate_summary.py ${samples_csv} fastqc_data summary.csv

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
