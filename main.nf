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
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

log.info """\
         CRISPR SCREEN PROCESSING PIPELINE
         ==================================
         input       : ${params.input}
         outdir      : ${params.outdir}
         """
         .stripIndent()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UMI2DEFLINE            } from './modules/local/umi2defline'

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
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow CRISPER_SCREEN_PROCESSING {

    ch_versions = Channel.empty()

    // 
    // Create channel from samplesheet 
    // 
    if (!params.input) { error "Please provide a samplesheet with --input" } 
    Channel 
        .fromPath(params.input, checkIfExists: true) 
        .splitCsv(header:true) 
        .map { create_fastq_channel(it) } 
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
    ch_versions = ch_versions.mix(UMI2DEFLINE.out.versions.first())

    // // Collect software versions // ch_versions .unique() .collectFile(name: 'software_versions.yml')

    // Output summary
    UMI2DEFLINE.out.reads.view { meta, reads ->
        "UMI extracted: ${meta.id} -> ${reads.name}"
    }

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    CRISPER_SCREEN_PROCESSING ()
}

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