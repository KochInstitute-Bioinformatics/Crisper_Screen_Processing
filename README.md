# CRISPR Screen Processing Pipeline

A Nextflow DSL2 pipeline for processing CRISPR screening data, starting with UMI extraction using umi_tools.

## Pipeline Overview

This pipeline processes CRISPR screening data through the following steps:

1. **UMI Extraction**: Uses umi_tools to extract UMIs from read 2 and move them to the defline, outputting processed read 1 with UMI information

## Usage

### Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=23.04.0`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(you can use [`Conda`](https://conda.io/miniconda.html) both to install Nextflow itself and also to manage software within pipelines. Please only use it within pipelines as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_.

3. Prepare your samplesheet (see [Input](#input) below)

4. Run the pipeline:

   ```bash
   nextflow run . -profile test,docker --outdir results
   ```

   > * The pipeline will auto-detect whether a sample is single- or paired-end using the information provided in the samplesheet.
   > * Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

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

## Parameters

### UMI Extraction Parameters

| Parameter     | Default                       | Description                           |
| ------------- | ----------------------------- | ------------------------------------- |
| `bc_pattern`  | `(?P<umi_1>.{11})CAAAAAA.*`   | Regex pattern for UMI extraction     |

## Output

### UMI Extraction

- `umi_extraction/`: Contains the UMI-extracted reads
  - `{sample}_with_umi.fastq.gz`: Read 1 with UMI information in the defline
  - `{sample}_extract.log`: umi_tools extraction log

### Pipeline Information

- `pipeline_info/`: Contains execution reports and pipeline information

## Directory Structure

```
Crisper_Screen_Processing/
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

- The nf-core framework: [Ewels et al., 2020](https://doi.org/10.1038/s41587-020-0439-x)
- UMI-tools: [Smith et al., 2017](https://doi.org/10.1101/gr.209601.116)
