# CRISPR Screen Processing Pipeline

A Nextflow DSL2 pipeline for processing CRISPR screening data, starting with UMI extraction using umi_tools.

## Pipeline Overview

This pipeline processes CRISPR screening data through the following steps:

1. **UMI Extraction** (`UMI2DEFLINE`): Extracts UMIs from read 2 and moves them to the defline of read 1
2. **Library Alignment** (`ALIGN2LIBRARY`): Aligns processed reads to the sgRNA library using Bowtie2
3. **UMI Deduplication** (`COLLAPSEUMI`): Collapses reads with identical UMIs to remove PCR duplicates

The pipeline takes paired-end FASTQ files as input and produces deduplicated BAM files for downstream analysis.

## Usage

### Quick Start

1. Install [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html#installation) (>=23.04.0)

2. Install container engine (Docker, Singularity, etc.)

3. Prepare your sgRNA library Bowtie2 index

4. Create your samplesheet (see [Input](#input) section)

5. Run the pipeline:

   ```bash
   nextflow run KochInstitute-Bioinformatics/CRISPR_Screen_Processing \
     --input samplesheet.csv \
     --bowtie2_index /path/to/your/library/index \
     --outdir results \
     -profile singularity

## Input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 4 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### Samplesheet Format

The samplesheet should contain the following columns:

| Column   | Description                              |
| -------- | ---------------------------------------- |
| `Sample` | Custom sample name                       |
| `Barcode`| Sample barcode (optional, can be empty)  |
| `Read1`  | Full path to FastQ file for Read 1      |
| `Read2`  | Full path to FastQ file for Read 2      |

An [example samplesheet](assets/samplesheet.csv) has been provided with the pipeline.

### Example Samplesheet

```csv
Sample,Barcode,Read1,Read2
Induction,,data/250916Kno_D25-12532_1_sequence_Induction.fastq.gz,data/250916Kno_D25-12532_2_sequence_Induction.fastq.gz
Male1_T0,,data/250916Kno_D25-12532_1_sequence_Male1_Ki67plus.fastq.gz,data/250916Kno_D25-12532_2_sequence_Male1_Ki67plus.fastq.gz
```

## Prerequisites

* **sgRNA Library**: You need a Bowtie2-indexed sgRNA library. Update the `bowtie2_index` parameter to point to your library.
* **UMI Pattern**: Ensure your UMI pattern matches your experimental design. The default pattern expects 11bp UMIs followed by "CAAAAAA".

### Core Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--input` | null | Path to samplesheet CSV file |
| `--outdir` | './results' | Output directory |
| `--bowtie2_index` | [path] | Path to Bowtie2 index for sgRNA library |
| `--bc_pattern` | `(?P<umi_1>.{11})CAAAAAA.*` | Regex pattern for UMI extraction |
| `--trim_3prime` | 31 | Number of bases to trim from 3' end |
| `--umi_separator` | '_' | Separator character for UMI in read names |
| `--extract_method` | 'read_id' | Method for UMI extraction |

## Output

### UMI Extraction

* `umi_extraction/`: Contains the UMI-extracted reads
  * `{sample}_with_umi.fastq.gz`: Read 1 with UMI information in the defline
  * `{sample}_extract.log`: umi_tools extraction log

### Library Alignment  

* `alignment/`: Contains alignment results
  * `{sample}.bam`: Aligned reads in BAM format
  * `{sample}.bam.bai`: BAM index file
  * `{sample}_alignment.log`: Alignment statistics

### UMI Deduplication

* `deduplication/`: Contains deduplicated results
  * `{sample}_deduplicated.bam`: Final deduplicated BAM file
  * `{sample}_dedup.log`: Deduplication statistics

### Pipeline Information

* `pipeline_info/`: Contains execution reports and pipeline information
  * `execution_timeline_*.html`: Timeline of pipeline execution
  * `execution_report_*.html`: Resource usage report
  * `execution_trace_*.txt`: Detailed execution trace
  * `pipeline_dag_*.html`: Pipeline workflow diagram

## Directory Structure

```{text}
CRISPR_Screen_Processing/
├── assets/                 # Sample data and schemas
├── bin/                    # Custom scripts and executables  
├── conf/                   # Configuration files
├── lib/                    # Custom library files
├── modules/
│   ├── local/             # Custom local modules
│   └── nf-core/           # nf-core modules
├── subworkflows/
│   ├── local/             # Custom local subworkflows  
│   └── nf-core/           # nf-core subworkflows
├── workflows/             # Main workflow definitions
├── main.nf               # Main pipeline script
├── nextflow.config       # Main configuration file
└── README.md             # This file
```

## Adding Custom Scripts

Place any custom Python scripts or other executables in the `bin/` directory. They will be automatically added to the PATH when the pipeline runs.

## Credits

This pipeline was developed using the [nf-core](https://nf-co.re/) template and follows DSL2 best practices.

## Citations

If you use this pipeline, please cite:

* **Nextflow**: Di Tommaso et al., 2017. Nextflow enables reproducible computational workflows. Nature Biotechnology 35, 316–319
* **UMI-tools**: Smith et al., 2017. UMI-tools: modeling sequencing errors in Unique Molecular Identifiers to improve quantification accuracy. Genome Research 27, 491-499
* **Bowtie2**: Langmead & Salzberg, 2012. Fast gapped-read alignment with Bowtie 2. Nature Methods 9, 357-359

