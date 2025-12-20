# CRISPR Screen Processing Pipeline

A Nextflow DSL2 pipeline for processing CRISPR screening data with comprehensive quality control, UMI-based deduplication, and MAGeCK count analysis.

## Pipeline Overview

This pipeline processes CRISPR screening data through the following steps:

1. **Quality Control - Raw Reads** (`FASTQC`): Quality assessment of raw paired-end reads
2. **UMI Extraction** (`UMI2DEFLINE`): Extracts UMIs from read 2 and moves them to the defline of read 1
3. **Quality Control - UMI Reads** (`FASTQC_UMI`): Quality assessment of UMI-extracted reads
4. **Library Alignment** (`ALIGN2LIBRARY`): Aligns processed reads to the sgRNA library using Bowtie2
5. **UMI Deduplication** (`COLLAPSEUMI`): Collapses reads with identical UMIs to remove PCR duplicates
6. **UMI Grouping** (`GROUPUMI`): Groups UMIs and annotates with sgRNA information
7. **MAGeCK Count - Deduplicated** (`MAGECKCOUNT`): Performs sgRNA counting on deduplicated BAMs
8. **MAGeCK Count - Non-Collapsed** (`MAGECKCOUNT_NOCOLLAPSE`): Performs sgRNA counting on aligned (non-deduplicated) BAMs
9. **Summary Report** (`GENERATE_SUMMARY`): Generates a comprehensive CSV summary with read counts and deduplication statistics

The pipeline takes paired-end FASTQ files as input and produces deduplicated BAM files, annotated UMI groups, MAGeCK count tables, and comprehensive quality reports for downstream analysis.

## Usage

### Quick Start

1. Install [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html#installation) (>=23.04.0)

2. Install container engine (Docker, Singularity, etc.)

3. Prepare your sgRNA library:
   - Bowtie2 index for alignment
   - sgRNA library file for MAGeCK (CSV format with sgRNA-to-gene mapping)
   - sgRNA annotations file for UMI grouping

4. Create your samplesheet (see [Input](#input) section)

5. Run the pipeline:

   ```bash
   nextflow run KochInstitute-Bioinformatics/CRISPR_Screen_Processing \
     --input samplesheet.csv \
     --bowtie2_index /path/to/your/library/index \
     --mageck_library /path/to/sgRNA_to_Gene.csv \
     --sgrna_annotations /path/to/sgRNA_to_Gene.csv \
     --outdir results \
     -profile singularity
   ```

## Input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 4 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### Samplesheet Format

The samplesheet should contain the following columns:

| Column    | Description                                                                    |
| --------- | ------------------------------------------------------------------------------ |
| `Sample`  | Custom sample name (will be used as sample identifier throughout the pipeline) |
| `Barcode` | Sample barcode (optional, can be empty)                                        |
| `Read1`   | Full path to FastQ file for Read 1                                             |
| `Read2`   | Full path to FastQ file for Read 2                                             |

An [example samplesheet](assets/samplesheet.csv) has been provided with the pipeline.

### Example Samplesheet

```csv
Sample,Barcode,Read1,Read2
Induction,,data/250916Kno_D25-12532_1_sequence_Induction.fastq.gz,data/250916Kno_D25-12532_2_sequence_Induction.fastq.gz
Male1_T0,,data/250916Kno_D25-12532_1_sequence_Male1_Ki67plus.fastq.gz,data/250916Kno_D25-12532_2_sequence_Male1_Ki67plus.fastq.gz
```

**Important Notes:**

- Sample names should be unique and will appear in MAGeCK output in the order specified in the samplesheet
- The sample order in the samplesheet determines the column order in MAGeCK count output files
- File paths can be absolute or relative to the launch directory

## Prerequisites

### Required Files

1. **sgRNA Library Bowtie2 Index**:
   - Pre-built Bowtie2 index for your sgRNA library
   - Specify the base name (without .1.bt2, .2.bt2 extensions)
   - Set with `--bowtie2_index` parameter

2. **MAGeCK Library File**:
   - CSV file mapping sgRNAs to genes
   - Required columns typically include sgRNA ID and gene name
   - Set with `--mageck_library` parameter

3. **sgRNA Annotations File**:
   - CSV file with sgRNA annotations for UMI grouping
   - Can be the same as MAGeCK library file
   - Set with `--sgrna_annotations` parameter

### UMI Pattern

Ensure your UMI pattern matches your experimental design. The default pattern expects 11bp UMIs followed by "CAAAAAA".

## Parameters

### Core Input/Output Parameters

| Parameter    | Default     | Description                                 |
|--------------|-------------|---------------------------------------------|
| `--input`    | null        | **[Required]** Path to samplesheet CSV file |
| `--outdir`   | './results' | Output directory for all results            |

### UMI Extraction Parameters

| Parameter            | Default                        | Description                                   |
| -------------------- | ------------------------------ | --------------------------------------------- |
| `--bc_pattern`       | `(?P<umi_1>.{11})CAAAAAA.*`    | Regex pattern for UMI extraction from Read 2  |
| `--extract_method`   | `'read_id'`                    | Method for UMI extraction (read_id or string) |

### Alignment Parameters

| Parameter         | Default | Description                                                      |
|-------------------|---------|------------------------------------------------------------------|
| `--bowtie2_index` | null    | **[Required]** Path to Bowtie2 index base name for sgRNA library |
| `--trim_3prime`   | 31      | Number of bases to trim from 3' end before alignment             |

### UMI Deduplication Parameters

| Parameter         | Default | Description                               |
|-------------------|---------|-------------------------------------------|
| `--umi_separator` | '_'     | Separator character for UMI in read names |

### MAGeCK Parameters

| Parameter              | Default           | Description                                                            |
| ---------------------- | ----------------- | ---------------------------------------------------------------------- |
| `--mageck_library`     | null              | **[Required]** Path to MAGeCK library file (sgRNA-to-gene mapping CSV) |
| `--mageck_prefix`      | 'mageck_analysis' | Output prefix for MAGeCK deduplicated analysis files                   |
| `--mageck_norm_method` | 'median'          | Normalization method for MAGeCK (median, total, control)               |

### sgRNA Annotation Parameters

| Parameter             | Default | Description                                                       |
| --------------------- | ------- | ----------------------------------------------------------------- |
| `--sgrna_annotations` | null    | **[Required]** Path to sgRNA annotation file for UMI grouping     |

### Resource Parameters

| Parameter | Default | Description |
| --------- | ------- | ----------- |
| `--max_memory` | '128.GB' | Maximum memory that can be requested |
| `--max_cpus` | 16 | Maximum CPUs that can be requested |
| `--max_time` | '240.h' | Maximum time that can be requested |

## Output

The pipeline produces organized output directories with comprehensive results:

### Quality Control

- `fastqc/`
  - `raw/`: FastQC reports for raw input reads
    - `{sample}_R1_fastqc.html`: Quality report for Read 1
    - `{sample}_R1_fastqc.zip`: Detailed QC data for Read 1
    - `{sample}_R2_fastqc.html`: Quality report for Read 2
    - `{sample}_R2_fastqc.zip`: Detailed QC data for Read 2
  - `umi/`: FastQC reports for UMI-extracted reads
    - `{sample}_umi_fastqc.html`: Quality report for UMI-extracted reads
    - `{sample}_umi_fastqc.zip`: Detailed QC data

### UMI Extraction

- `umi_extraction/`: Contains the UMI-extracted reads
  - `{sample}_with_umi.fastq.gz`: Read 1 with UMI information moved to the defline
  - `{sample}_extract.log`: umi_tools extraction log with statistics

### Library Alignment  

- `alignment/`: Contains alignment results
  - `{sample}.bam`: Aligned reads in BAM format
  - `{sample}.bam.bai`: BAM index file for quick access
  - `{sample}_alignment.log`: Bowtie2 alignment statistics

### UMI Deduplication

- `deduplication/`: Contains deduplicated results
  - `{sample}_deduplicated.bam`: Final deduplicated BAM file with PCR duplicates removed
  - `{sample}_deduplicated.bam.bai`: BAM index file
  - `{sample}_dedup.log`: Deduplication statistics from umi_tools
  - `{sample}_dedup_stats.tsv`: Detailed deduplication metrics

### UMI Grouping and Annotation

- `umi_grouping/`: Contains UMI grouping results
  - `{sample}.groups.tsv`: Raw UMI group assignments
  - `{sample}.groups.annotated.tsv`: UMI groups annotated with sgRNA information
  - `{sample}.group.log`: UMI grouping log

### MAGeCK Count Analysis

- `mageck/`: Contains MAGeCK count analysis results
  - **Deduplicated analysis:**
    - `mageck_analysis.count.txt`: Read counts per sgRNA (deduplicated)
    - `mageck_analysis.countsummary.txt`: Summary statistics (deduplicated)
    - `mageck_analysis.count_normalized.txt`: Normalized counts (deduplicated)
    - `mageck_analysis.log`: MAGeCK execution log (deduplicated)
  - **Non-collapsed analysis:**
    - `mageck_analysis_noCollapse.count.txt`: Read counts per sgRNA (all aligned reads)
    - `mageck_analysis_noCollapse.countsummary.txt`: Summary statistics (all reads)
    - `mageck_analysis_noCollapse.count_normalized.txt`: Normalized counts (all reads)
    - `mageck_analysis_noCollapse.log`: MAGeCK execution log (all reads)

### Summary Report

- `summary.csv`: Comprehensive CSV file containing:
  - Sample names and processing status
  - Raw read counts from FastQC
  - UMI-extracted read counts
  - Alignment statistics
  - Deduplication rates and final counts
  - Overall pipeline metrics

### Pipeline Information

- `pipeline_info/`: Contains execution reports and pipeline information
  - `execution_timeline_*.html`: Timeline visualization of pipeline execution
  - `execution_report_*.html`: Detailed resource usage report
  - `execution_trace_*.txt`: Complete execution trace with all tasks
  - `pipeline_dag_*.html`: Visual pipeline workflow diagram

## Understanding the Output

### Two MAGeCK Analyses

The pipeline runs MAGeCK count **twice** to provide complementary perspectives:

1. **Deduplicated Analysis** (`mageck_analysis.*`):
   - Uses UMI-deduplicated BAM files
   - Removes PCR duplicates based on UMI information
   - Provides more accurate biological representation
   - Better for downstream enrichment/depletion analysis
   - **Recommended for final analysis**

2. **Non-Collapsed Analysis** (`mageck_analysis_noCollapse.*`):
   - Uses aligned BAM files without UMI deduplication
   - Includes all aligned reads (with PCR duplicates)
   - Useful for quality control and comparison
   - Shows raw alignment abundance

### Sample Order in MAGeCK Output

The columns in MAGeCK count tables follow the **exact order** of samples in your input samplesheet. This is important for:

- Consistent analysis across runs
- Proper interpretation of count matrices
- Downstream statistical analysis

## Directory Structure

```text
CRISPR_Screen_Processing/
├── assets/                 # Sample data and schemas
├── bin/                    # Custom scripts and executables
│   ├── annotate_umi_groups.py    # Annotates UMI groups with sgRNA info
│   └── generate_summary.py       # Creates comprehensive summary CSV
├── conf/                   # Configuration files
│   ├── base.config        # Resource requirements
│   ├── modules.config     # Module-specific options
│   └── test.config        # Test data configuration
├── modules/
│   ├── local/             # Custom local modules
│   │   ├── align2library.nf     # Bowtie2 alignment
│   │   ├── collapseumi.nf       # UMI deduplication
│   │   ├── generate_summary.nf  # Summary generation
│   │   ├── groupumi.nf          # UMI grouping
│   │   ├── mageckcount.nf       # MAGeCK counting
│   │   └── umi2defline.nf       # UMI extraction
│   └── nf-core/           # nf-core modules
│       └── fastqc/        # FastQC quality control
├── main.nf                # Main pipeline script
├── nextflow.config        # Main configuration file
└── README.md              # This file
```

## Customization

### Modifying UMI Extraction Pattern

The UMI extraction pattern can be customized to match your library design:

```bash
# Default: 11bp UMI followed by CAAAAAA
--bc_pattern '(?P<umi_1>.{11})CAAAAAA.*'

# Example: 8bp UMI followed by TTTTTT
--bc_pattern '(?P<umi_1>.{8})TTTTTT.*'

# Example: 12bp UMI with different linker
--bc_pattern '(?P<umi_1>.{12})GGGGGG.*'
```

### Adjusting Resource Requirements

Modify `conf/base.config` to adjust memory, CPU, and time requirements for specific processes based on your compute environment and data size.

### Adding Custom Processing Steps

1. Create a new module in `modules/local/`
2. Follow the existing module structure
3. Include in `main.nf` with: `include { MODULE_NAME } from './modules/local/modulename'`
4. Add to the workflow in the appropriate location

## Container Support

The pipeline supports multiple container engines:

- **Docker**: `-profile docker`
- **Singularity**: `-profile singularity`
- **Podman**: `-profile podman`

All required software is automatically downloaded and managed through containers:

- UMI-tools for UMI extraction, deduplication, and grouping
- Bowtie2 for alignment
- FastQC for quality control
- MAGeCK for sgRNA counting
- Python 3.11 for summary generation

## Configuration Profiles

Available profiles:

- `docker`: Use Docker containers
- `singularity`: Use Singularity containers
- `podman`: Use Podman containers
- `test`: Run with test configuration
- `debug`: Print hostname before each process

Profiles can be combined: `-profile test,docker`

## Troubleshooting

### Common Issues

1. **File not found errors**:
   - Ensure all paths in the samplesheet are correct (absolute or relative to launch directory)
   - Check that Bowtie2 index files exist and the path is the base name

2. **Memory errors**:
   - Increase `--max_memory` parameter
   - Adjust process-specific memory in `conf/base.config`

3. **UMI extraction failures**:
   - Verify your `--bc_pattern` matches your library design
   - Check Read 2 quality and length in FastQC reports

4. **MAGeCK errors**:
   - Ensure library file format matches MAGeCK requirements
   - Verify sample names don't contain special characters
   - Check that BAM files contain aligned reads

5. **Container issues**:
   - Ensure container engine is properly installed and accessible
   - For Singularity, check bind paths include all necessary directories

## Credits

This pipeline was developed by the Koch Institute Bioinformatics team using the [nf-core](https://nf-co.re/) template and follows DSL2 best practices.

## Citations

If you use this pipeline, please cite:

- **Nextflow**: Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. Nextflow enables reproducible computational workflows. Nat Biotechnol. 2017 Apr 11;35(4):316-319. doi: 10.1038/nbt.3820.

- **UMI-tools**: Smith T, Heger A, Sudbery I. UMI-tools: modeling sequencing errors in Unique Molecular Identifiers to improve quantification accuracy. Genome Res. 2017 Mar;27(3):491-499. doi: 10.1101/gr.209601.116.

- **Bowtie2**: Langmead B, Salzberg SL. Fast gapped-read alignment with Bowtie 2. Nat Methods. 2012 Mar 4;9(4):357-9. doi: 10.1038/nmeth.1923.

- **FastQC**: Andrews S. (2010). FastQC: A Quality Control Tool for High Throughput Sequence Data. Available online at: <http://www.bioinformatics.babraham.ac.uk/projects/fastqc/>

- **MAGeCK**: Li W, Xu H, Xiao T, Cong L, Love MI, Zhang F, Irizarry RA, Liu JS, Brown M, Liu XS. MAGeCK enables robust identification of essential genes from genome-scale CRISPR/Cas9 knockout screens. Genome Biol. 2014;15(12):554. doi: 10.1186/s13059-014-0554-4.

## License

This pipeline is released under the MIT License. See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please visit: <https://github.com/KochInstitute-Bioinformatics/CRISPR_Screen_Processing>
