# CRISPR Screen Processing Pipeline - Usage Guide

This guide provides detailed instructions for running the CRISPR Screen Processing pipeline and understanding its components.

## Quick Start

### 1. Prerequisites Check

Ensure you have:

- Nextflow >= 23.04.0 installed
- Container engine (Docker, Singularity, or Podman)
- Access to your FASTQ files
- sgRNA library files prepared

### 2. Prepare Required Files

#### A. Input Samplesheet (Required)

Create a CSV file with your samples:

```csv
Sample,Barcode,Read1,Read2
Control_T0,,/path/to/control_R1.fastq.gz,/path/to/control_R2.fastq.gz
Treatment_Day7,,/path/to/treatment_R1.fastq.gz,/path/to/treatment_R2.fastq.gz
Treatment_Day14,,/path/to/treatment2_R1.fastq.gz,/path/to/treatment2_R2.fastq.gz
```

**Important:**

- Sample order matters! It determines column order in MAGeCK output
- Use consistent, informative sample names
- Barcode column can be empty
- Use absolute paths or paths relative to launch directory

#### B. sgRNA Library Files (Required)

You need three library-related files:

1. **Bowtie2 Index** (`--bowtie2_index`):

   ```bash
   # If you have index files like:
   # library.1.bt2, library.2.bt2, etc.
   # Specify just the base name:
   --bowtie2_index /path/to/library
   ```

2. **MAGeCK Library** (`--mageck_library`):
   - CSV format with sgRNA-to-gene mapping
   - Typical columns: sgRNA_ID, Gene, Sequence

   ```csv
   sgRNA_ID,Gene,Sequence
   sgRNA_0001,GENE1,ACGTACGTACGTACGT
   sgRNA_0002,GENE1,TGCATGCATGCATGCA
   ```

3. **sgRNA Annotations** (`--sgrna_annotations`):
   - CSV format with sgRNA annotations
   - Can be the same file as MAGeCK library
   - Used for annotating UMI groups

### 3. Test the Pipeline Configuration

Before running with your data, validate the configuration:

```bash
# Check configuration syntax
nextflow config main.nf

# Run with test profile (if available)
nextflow run main.nf -profile test,docker
```

### 4. Run the Pipeline

#### Basic Run

```bash
nextflow run KochInstitute-Bioinformatics/CRISPR_Screen_Processing \
  --input samplesheet.csv \
  --bowtie2_index /path/to/library/index \
  --mageck_library /path/to/sgRNA_library.csv \
  --sgrna_annotations /path/to/sgRNA_annotations.csv \
  --outdir results \
  -profile docker
```

#### With Custom Parameters

```bash
nextflow run KochInstitute-Bioinformatics/CRISPR_Screen_Processing \
  --input samplesheet.csv \
  --bowtie2_index /path/to/library/index \
  --mageck_library /path/to/sgRNA_library.csv \
  --sgrna_annotations /path/to/sgRNA_annotations.csv \
  --outdir results \
  --bc_pattern '(?P<umi_1>.{8})TTTTTT.*' \
  --trim_3prime 25 \
  --mageck_prefix my_screen \
  --mageck_norm_method total \
  -profile singularity \
  -resume
```

## Understanding Pipeline Components

### 1. Quality Control with FastQC

The pipeline runs FastQC **twice**:

**First run**: On raw input reads

- Assesses base quality, GC content, adapter content
- Helps identify sequencing quality issues
- Output: `fastqc/raw/`

**Second run**: After UMI extraction

- Verifies UMI extraction didn't introduce artifacts
- Checks read quality after processing
- Output: `fastqc/umi/`

**What to look for:**

- Per base sequence quality should be high (>28)
- No unexpected adapter contamination
- Reasonable sequence length distribution

### 2. UMI Extraction (UMI2DEFLINE)

Extracts Unique Molecular Identifiers (UMIs) from Read 2 and appends them to Read 1 headers.

**How it works:**

1. Reads the UMI pattern from Read 2
2. Extracts UMI sequence based on `--bc_pattern`
3. Trims constant sequence (e.g., "CAAAAAA")
4. Appends UMI to Read 1 defline with separator

**Customizing UMI pattern:**

```bash
# Default: 11bp UMI + CAAAAAA linker
--bc_pattern '(?P<umi_1>.{11})CAAAAAA.*'

# 8bp UMI with TTTTTT linker
--bc_pattern '(?P<umi_1>.{8})TTTTTT.*'

# 12bp UMI with GGGGGG linker
--bc_pattern '(?P<umi_1>.{12})GGGGGG.*'

# Multiple UMIs (if needed)
--bc_pattern '(?P<umi_1>.{6})(?P<umi_2>.{6})CAAAAAA.*'
```

**Output:**

- `{sample}_with_umi.fastq.gz`: Processed reads
- `{sample}_extract.log`: Extraction statistics

### 3. Library Alignment (ALIGN2LIBRARY)

Aligns UMI-extracted reads to your sgRNA library using Bowtie2.

**Parameters:**

- `--bowtie2_index`: Path to Bowtie2 index (base name)
- `--trim_3prime`: Bases to trim from 3' end (default: 31)

**Alignment strategy:**

- Local alignment mode
- Allows mismatches for biological variability
- Reports best alignment per read

**Output:**

- `{sample}.bam`: Aligned reads
- `{sample}.bam.bai`: BAM index
- `{sample}_alignment.log`: Alignment statistics

**Interpreting alignment logs:**

- Overall alignment rate should be >70% for good quality
- Low alignment may indicate library mismatch or quality issues

### 4. UMI Deduplication (COLLAPSEUMI)

Removes PCR duplicates using UMI information.

**How it works:**

1. Groups reads by genomic position
2. Within each position, groups by UMI sequence
3. Keeps one representative read per UMI group
4. Produces deduplicated BAM file

**Parameters:**

- `--umi_separator`: Character separating UMI from read name (default: '_')
- `--extract_method`: How UMI was added (default: 'read_id')

**Output:**

- `{sample}_deduplicated.bam`: Deduplicated BAM
- `{sample}_dedup.log`: Deduplication statistics
- `{sample}_dedup_stats.tsv`: Detailed metrics

**Expected deduplication rates:**

- Varies by PCR cycles and complexity
- Typical range: 30-70% reads removed
- Higher removal expected with more PCR cycles

### 5. UMI Grouping (GROUPUMI)

Groups similar UMIs and annotates with sgRNA information.

**Purpose:**

- Accounts for sequencing errors in UMIs
- Groups UMIs within edit distance threshold
- Links UMI groups to sgRNA targets

**Parameters:**

- `--sgrna_annotations`: Annotation file path

**Output:**

- `{sample}.groups.tsv`: Raw UMI groups
- `{sample}.groups.annotated.tsv`: Annotated groups
- `{sample}.group.log`: Grouping statistics

### 6. MAGeCK Count Analysis

The pipeline runs MAGeCK count **twice** on each sample set:

#### A. Deduplicated Analysis (Recommended)

```bash
# Automatically run with prefix from --mageck_prefix
```

**Uses:** UMI-deduplicated BAM files  
**Purpose:** Accurate biological representation  
**Output prefix:** `mageck_analysis` (or your custom prefix)

**When to use:**

- Primary analysis for biological conclusions
- Enrichment/depletion screens
- Publication-quality results

#### B. Non-Collapsed Analysis (Quality Control)

```bash
# Automatically run with suffix "_noCollapse"
```

**Uses:** Aligned BAM files (with duplicates)  
**Purpose:** QC comparison, raw abundance  
**Output prefix:** `mageck_analysis_noCollapse`

**When to use:**

- Quality control checks
- Comparing deduplication impact
- Assessing library complexity

**Parameters:**

- `--mageck_library`: sgRNA-to-gene mapping file
- `--mageck_prefix`: Output file prefix (default: "mageck_analysis")
- `--mageck_norm_method`: Normalization method (median, total, control)

**MAGeCK Output Files:**

- `.count.txt`: Raw count matrix (samples as columns)
- `.countsummary.txt`: Summary statistics per sample
- `.count_normalized.txt`: Normalized count matrix
- `.log`: Execution log and parameters

**Sample order in output:**
The columns in count files follow the **exact order** in your samplesheet!

### 7. Summary Report (GENERATE_SUMMARY)

Generates a comprehensive CSV with all key metrics.

**Includes:**

- Raw read counts per sample
- UMI-extracted read counts
- Alignment statistics and rates
- Deduplication rates
- Final deduplicated read counts
- Per-sample processing summary

**Output:** `summary.csv`

**Use cases:**

- Quick overview of all samples
- Quality control across batch
- Identifying outlier samples
- Documentation for methods sections

## Advanced Usage

### Resuming Failed Runs

Nextflow supports automatic resume functionality:

```bash
nextflow run main.nf \
  --input samplesheet.csv \
  [other parameters] \
  -resume
```

This will skip successfully completed steps and only rerun failed or new steps.

### Running on HPC Clusters

#### SLURM Example

Create a custom config file `slurm.config`:

```groovy
process {
  executor = 'slurm'
  queue = 'normal'
  clusterOptions = '--account=myaccount'
  
  withLabel: process_low {
    cpus = 2
    memory = 8.GB
    time = 4.h
  }
  
  withLabel: process_medium {
    cpus = 8
    memory = 32.GB
    time = 12.h
  }
  
  withLabel: process_high {
    cpus = 16
    memory = 64.GB
    time = 24.h
  }
}

singularity {
  enabled = true
  autoMounts = true
}
```

Run with:

```bash
nextflow run main.nf -c slurm.config -profile singularity [other params]
```

### Processing Large Datasets

For large CRISPR screens (100+ samples):

1. **Increase resource limits:**

   ```bash
   --max_memory 256.GB \
   --max_cpus 32 \
   --max_time 480.h
   ```

2. **Use scratch space for work directory:**

   ```bash
   nextflow run main.nf \
     -w /scratch/$USER/work \
     [other parameters]
   ```

3. **Enable automatic cleanup:**

   ```groovy
   // Add to nextflow.config
   cleanup = true
   ```

### Custom UMI Processing

#### Different UMI lengths

```bash
# 6bp UMI
--bc_pattern '(?P<umi_1>.{6})CAAAAAA.*'

# 16bp UMI
--bc_pattern '(?P<umi_1>.{16})CAAAAAA.*'
```

#### No constant linker sequence

```bash
# Extract first N bases as UMI
--bc_pattern '(?P<umi_1>.{11}).*'
```

#### Multiple UMIs

```bash
# Two UMIs of different lengths
--bc_pattern '(?P<umi_1>.{8})(?P<umi_2>.{8})CAAAAAA.*'
```

### Customizing MAGeCK Analysis

#### Different normalization methods

```bash
# Median normalization (default, recommended)
--mageck_norm_method median

# Total read count normalization
--mageck_norm_method total

# Control sgRNA normalization
--mageck_norm_method control
```

#### Multiple MAGeCK runs

To run MAGeCK with different parameters, you can:

1. Run pipeline once to get deduplicated BAMs
2. Run MAGeCK separately on the BAM outputs
3. Or modify the pipeline to add additional MAGeCK processes

## Directory Structure Details

```text
results/
├── fastqc/                          # Quality control
│   ├── raw/                         # FastQC on original reads
│   │   ├── Sample1_R1_fastqc.html
│   │   ├── Sample1_R1_fastqc.zip
│   │   ├── Sample1_R2_fastqc.html
│   │   └── Sample1_R2_fastqc.zip
│   └── umi/                         # FastQC on UMI-extracted reads
│       ├── Sample1_umi_fastqc.html
│       └── Sample1_umi_fastqc.zip
├── umi_extraction/                  # UMI processing
│   ├── Sample1_with_umi.fastq.gz
│   └── Sample1_extract.log
├── alignment/                       # Bowtie2 alignment
│   ├── Sample1.bam
│   ├── Sample1.bam.bai
│   └── Sample1_alignment.log
├── deduplication/                   # UMI deduplication
│   ├── Sample1_deduplicated.bam
│   ├── Sample1_deduplicated.bam.bai
│   ├── Sample1_dedup.log
│   └── Sample1_dedup_stats.tsv
├── umi_grouping/                    # UMI grouping
│   ├── Sample1.groups.tsv
│   ├── Sample1.groups.annotated.tsv
│   └── Sample1.group.log
├── mageck/                          # MAGeCK analysis
│   ├── mageck_analysis.count.txt            # Deduplicated
│   ├── mageck_analysis.countsummary.txt
│   ├── mageck_analysis.count_normalized.txt
│   ├── mageck_analysis.log
│   ├── mageck_analysis_noCollapse.count.txt # Non-collapsed
│   ├── mageck_analysis_noCollapse.countsummary.txt
│   ├── mageck_analysis_noCollapse.count_normalized.txt
│   └── mageck_analysis_noCollapse.log
├── summary.csv                      # Comprehensive summary
└── pipeline_info/                   # Execution reports
    ├── execution_timeline_*.html
    ├── execution_report_*.html
    ├── execution_trace_*.txt
    └── pipeline_dag_*.html
```

## Best Practices

### 1. Experimental Design

- **Controls**: Include T0 or reference samples
- **Replicates**: Biological replicates improve statistical power
- **Sample naming**: Use consistent, informative names
- **Documentation**: Record all parameters and library versions

### 2. Quality Control Checks

After pipeline completion, review:

✅ **FastQC reports**: Check for quality issues  
✅ **Alignment rates**: Should be >70% for good screens  
✅ **Deduplication rates**: Typical range 30-70%  
✅ **Summary.csv**: Compare metrics across samples  
✅ **MAGeCK countsummary**: Check read distribution  

### 3. Data Analysis Workflow

1. Run this pipeline → Get count matrices
2. Load count matrices into R/Python
3. Perform differential analysis (MAGeCK RRA, MAGeCK MLE, or custom)
4. Identify enriched/depleted sgRNAs/genes
5. Validate top hits

### 4. Reproducibility

- **Document parameters**: Save your exact command
- **Version control**: Note Nextflow and pipeline versions
- **Archive inputs**: Keep original FASTQs and samplesheet
- **Share configuration**: Provide config files with publications

### 5. Resource Planning

Typical resource requirements per sample:

| Step | CPUs | Memory | Time |
| ------ | ------ | -------- | ------ |
| FastQC | 2 | 4 GB | 15 min |
| UMI extraction | 4 | 8 GB | 30 min |
| Alignment | 8 | 16 GB | 1-2 hr |
| Deduplication | 4 | 16 GB | 30 min |
| UMI grouping | 4 | 16 GB | 30 min |
| MAGeCK count | 4 | 8 GB | 15 min |

Adjust based on your data size (typical values for 10M reads per sample).

## Troubleshooting

### Issue: Low alignment rate (<50%)

**Possible causes:**

- Wrong Bowtie2 index
- UMI pattern doesn't match data
- Excessive 3' trimming

**Solutions:**

1. Verify Bowtie2 index matches your library
2. Check FastQC reports for quality issues
3. Adjust `--trim_3prime` parameter
4. Verify `--bc_pattern` with your library design

### Issue: Very high deduplication (>90%)

**Possible causes:**

- Low library complexity
- Excessive PCR amplification
- Contamination

**Solutions:**

1. Review PCR protocol
2. Check library preparation steps
3. Compare with non-collapsed MAGeCK results
4. Consider if this is expected for your experiment

### Issue: Sample order mismatch in MAGeCK

**Solution:**

- Ensure samplesheet order matches your experimental design
- MAGeCK output follows samplesheet order exactly
- Re-run with corrected samplesheet if needed

### Issue: Memory errors

**Solutions:**

```bash
# Increase max memory
--max_memory 256.GB

# Or adjust per-process memory in conf/base.config
process {
  withName: ALIGN2LIBRARY {
    memory = { 32.GB * task.attempt }
  }
}
```

### Issue: Container binding errors (Singularity)

**Solution:**
Add necessary paths to bind in `nextflow.config`:

```groovy
singularity {
  enabled = true
  autoMounts = true
  runOptions = '--bind /path/to/data:/path/to/data'
}
```

## Adding Custom Modules

Want to extend the pipeline? Here's how:

### 1. Create a new module

Create `modules/local/mymodule.nf`:

```groovy
process MYMODULE {
    tag "$meta.id"
    label 'process_medium'
    
    container 'docker://mycontainer:latest'
    
    input:
    tuple val(meta), path(input_file)
    
    output:
    tuple val(meta), path("*.output"), emit: results
    path "versions.yml", emit: versions
    
    script:
    def prefix = "${meta.id}"
    """
    my_tool -i ${input_file} -o ${prefix}.output
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        my_tool: \$(my_tool --version)
    END_VERSIONS
    """
}
```

### 2. Include in main workflow

In `main.nf`:

```groovy
include { MYMODULE } from './modules/local/mymodule'

// In workflow:
MYMODULE (
    SOME_PREVIOUS_STEP.out.results
)
```

### 3. Configure resources

In `conf/modules.config`:

```groovy
process {
    withName: MYMODULE {
        cpus = 4
        memory = 16.GB
        time = 4.h
    }
}
```

## Getting Help

### Resources

- **Pipeline GitHub**: <https://github.com/KochInstitute-Bioinformatics/CRISPR_Screen_Processing>
- **Nextflow Documentation**: <https://www.nextflow.io/docs/latest/>
- **nf-core Best Practices**: <https://nf-co.re/docs/contributing/guidelines>

### Reporting Issues

When reporting issues, include:

1. Full command used
2. Nextflow version (`nextflow -version`)
3. Error message or unexpected behavior
4. Relevant log files from `work/` directory
5. Samplesheet (with sensitive paths removed)

### Common Questions

**Q: Can I process single-end reads?**  
A: Currently, the pipeline requires paired-end reads. Modifications would be needed for single-end support.

**Q: Can I skip UMI processing?**  
A: The pipeline is designed around UMI-based deduplication. Skipping would require significant modifications.

**Q: How do I update the pipeline?**  
A: Pull the latest version from GitHub:

```bash
nextflow pull KochInstitute-Bioinformatics/CRISPR_Screen_Processing
```

**Q: Can I run only specific steps?**  
A: Nextflow doesn't support selective step execution easily. Consider modifying the workflow or using intermediate outputs.

**Q: Where are the temporary files?**  
A: In the `work/` directory. Clean up with:

```bash
nextflow clean -f
```

## Next Steps

After running this pipeline:

1. **Review outputs**: Check quality metrics in `summary.csv`
2. **MAGeCK analysis**: Use count files for downstream analysis
3. **Statistical testing**: Run MAGeCK RRA/MLE or custom analyses
4. **Visualization**: Create plots of enriched/depleted sgRNAs
5. **Validation**: Plan follow-up experiments for top hits

Consult the MAGeCK documentation for guidance on downstream statistical analysis:

- <https://sourceforge.net/p/mageck/wiki/Home/>
