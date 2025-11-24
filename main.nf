#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Crisper_Screen_Processing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CRISPR Screen Processing Pipeline
    Github : 
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from './modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_UMI   } from './modules/nf-core/fastqc/main'
include { GENERATE_SUMMARY       } from './modules/local/generate_summary'
include { UMI2DEFLINE            } from './modules/local/umi2defline'
include { ALIGN2LIBRARY          } from './modules/local/align2library'
include { COLLAPSEUMI            } from './modules/local/collapseumi'
include { MAGECKCOUNT            } from './modules/local/mageckcount'
include { MAGECKCOUNT as MAGECKCOUNT_NOCOLLAPSE } from './modules/local/mageckcount'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
// include { FASTQC  } from './modules/nf-core/fastqc/main'
// include { MULTIQC } from './modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id           = row.Sample
    meta.barcode      = row.Barcode

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []
    if (!file(row.Read1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read1 does not exist!\n${row.Read1}"
    }
    if (!file(row.Read2).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read2 does not exist!\n${row.Read2}"
    }

    fastq_meta = [ meta, [ file(row.Read1), file(row.Read2) ] ]
    
    return fastq_meta
}

// Function to extract sample order from samplesheet for MAGeCK
def get_sample_order(samplesheet_path) {
    def sample_order = []
    file(samplesheet_path).splitCsv(header: true).each { row ->
        sample_order.add(row.Sample)
    }
    return sample_order
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CRISPER_SCREEN_PROCESSING {
    
    // Print parameter summary
    log.info """\
             CRISPR SCREEN PROCESSING PIPELINE
             ==================================
             input           : ${params.input}
             outdir          : ${params.outdir}
             bowtie2_index   : ${params.bowtie2_index}
             trim_3prime     : ${params.trim_3prime}
             umi_separator   : ${params.umi_separator}
             extract_method  : ${params.extract_method}
             mageck_library  : ${params.mageck_library}
             mageck_prefix   : ${params.mageck_prefix}
             """
             .stripIndent()

    // 
    // Create channel from samplesheet 
    // 
    if (!params.input) { error "Please provide a samplesheet with --input" } 
    
    channel 
        .fromPath(params.input, checkIfExists: true) 
        .splitCsv(header:true) 
        .map { row -> create_fastq_channel(row) } 
        .set { ch_raw_reads }

    ch_raw_reads.view { meta, reads ->
        "Sample: ${meta.id}, Reads: ${reads[0].name}, ${reads[1].name}"
    }

    //
    // MODULE: FastQC - Quality control and read counting
    //
    FASTQC (
        ch_raw_reads
    )

    // Output summary
    FASTQC.out.zip.view { meta, zip ->
        "FastQC completed: ${meta.id}"
    }

    //
    // MODULE: UMI extraction
    //
    UMI2DEFLINE (
        ch_raw_reads
    )

    // Output summary
    UMI2DEFLINE.out.reads.view { meta, reads ->
        "UMI extracted: ${meta.id} -> ${reads.name}"
    }

        //
    // MODULE: FastQC on UMI-extracted reads
    //
    FASTQC_UMI (
        UMI2DEFLINE.out.reads
    )

    // Output summary
    FASTQC_UMI.out.zip.view { meta, zip ->
        "FastQC UMI completed: ${meta.id}"
    }

    //
    // MODULE: Alignment to library
    //
    ALIGN2LIBRARY (
        UMI2DEFLINE.out.reads
    )

    // Output summary
    ALIGN2LIBRARY.out.bam.view { meta, bam ->
        "Alignment completed: ${meta.id} -> ${bam.name}"
    }

    //
    // MODULE: UMI deduplication
    //
    COLLAPSEUMI (
        ALIGN2LIBRARY.out.bam.join(ALIGN2LIBRARY.out.bai)
    )

    // Output summary
    COLLAPSEUMI.out.bam.view { meta, bam ->
        "UMI deduplication completed: ${meta.id} -> ${bam.name}"
    }

    // Output summary for stats
    COLLAPSEUMI.out.stats.view { stats ->
        "UMI deduplication stats: ${stats.name}"
    }

    //
    // MODULE: MAGeCK count on deduplicated BAMs
    //
    // Get sample order from the original samplesheet
    def sample_order = get_sample_order(params.input)
    
    // Create a map of sample_id -> deduplicated bam_file with published paths
    COLLAPSEUMI.out.bam
        .map { meta, bam -> 
            // Use the published output path instead of work directory path
            def published_path = "${params.outdir}/deduplication/${meta.id}_deduplicated.bam"
            return [meta.id, published_path]
        }
        .collectFile(name: 'sample_bam_mapping_dedup.txt', newLine: true) { sample_id, bam_path ->
            "${sample_id}\t${bam_path}"
        }
        .map { mapping_file ->
            // Read the mapping and create ordered BAM list
            def sample_to_bam = [:]
            mapping_file.text.split('\n').findAll { it.trim() }.each { line ->
                def parts = line.split('\t')
                sample_to_bam[parts[0]] = parts[1]
            }
            
            // Create ordered list based on sample_order
            def ordered_bams = sample_order.collect { sample_id ->
                sample_to_bam[sample_id]
            }.findAll { it != null }  // Remove any null entries
            
            // Create a new file with ordered BAM paths
            def ordered_file = file("${workDir}/ordered_bams_dedup.txt")
            ordered_file.text = ordered_bams.join('\n')
            return ordered_file
        }
        .set { ch_ordered_bam_list_dedup }
    
    // Run MAGeCK count on deduplicated BAMs
    MAGECKCOUNT (
        ch_ordered_bam_list_dedup,
        params.mageck_library,
        sample_order,
        params.mageck_prefix
    )
    
    //
    // MODULE: MAGeCK count on non-collapsed (aligned) BAMs
    //
    // Create a map of sample_id -> aligned (non-collapsed) bam_file with published paths
    ALIGN2LIBRARY.out.bam
        .map { meta, bam -> 
            // Use the published output path instead of work directory path
            def published_path = "${params.outdir}/alignment/${meta.id}.sorted.bam"
            return [meta.id, published_path]
        }
        .collectFile(name: 'sample_bam_mapping_aligned.txt', newLine: true) { sample_id, bam_path ->
            "${sample_id}\t${bam_path}"
        }
        .map { mapping_file ->
            // Read the mapping and create ordered BAM list
            def sample_to_bam = [:]
            mapping_file.text.split('\n').findAll { it.trim() }.each { line ->
                def parts = line.split('\t')
                sample_to_bam[parts[0]] = parts[1]
            }
            
            // Create ordered list based on sample_order
            def ordered_bams = sample_order.collect { sample_id ->
                sample_to_bam[sample_id]
            }.findAll { it != null }  // Remove any null entries
            
            // Create a new file with ordered BAM paths
            def ordered_file = file("${workDir}/ordered_bams_aligned.txt")
            ordered_file.text = ordered_bams.join('\n')
            return ordered_file
        }
        .set { ch_ordered_bam_list_aligned }
    
    // Run MAGeCK count on non-collapsed BAMs with different prefix
    MAGECKCOUNT_NOCOLLAPSE (
        ch_ordered_bam_list_aligned,
        params.mageck_library,
        sample_order,
        "mageck_analysis_noCollapse"
    )

    //
    // MODULE: Generate summary CSV with read counts
    //
    // Collect all FastQC zip files from raw reads
    FASTQC.out.zip
        .map { meta, zips -> zips }
        .flatten()
        .collect()
        .set { ch_all_fastqc_zips }
    
    // Collect all FastQC zip files from UMI-extracted reads
    FASTQC_UMI.out.zip
        .map { meta, zips -> zips }
        .flatten()
        .collect()
        .set { ch_all_fastqc_umi_zips }
    
    // Collect all deduplication log files
    COLLAPSEUMI.out.log
        .collect()
        .set { ch_all_dedup_logs }
    
    // Generate summary with read counts and deduplication statistics
    GENERATE_SUMMARY (
        file(params.input),
        ch_all_fastqc_zips,
        ch_all_fastqc_umi_zips,
        ch_all_dedup_logs
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION HANDLER
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow.onComplete {
    log.info "Pipeline completed!"
    log.info "Results saved to: ${params.outdir}"
    log.info "Execution status: ${workflow.success ? 'SUCCESS' : 'FAILED'}"
    log.info "Execution duration: ${workflow.duration}"
    log.info "CPU hours: ${workflow.stats.computeTimeFmt ?: 'N/A'}"
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MAIN ENTRY WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    CRISPER_SCREEN_PROCESSING ()
}