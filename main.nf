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

include { UMI2DEFLINE            } from './modules/local/umi2defline'
include { ALIGN2LIBRARY          } from './modules/local/align2library'
include { COLLAPSEUMI            } from './modules/local/collapseumi'

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
        ALIGN2LIBRARY.out.bam
    )

    // Output summary
    COLLAPSEUMI.out.bam.view { meta, bam ->
        "UMI deduplication completed: ${meta.id} -> ${bam.name}"
    }

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