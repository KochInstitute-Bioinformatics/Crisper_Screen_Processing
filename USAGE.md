# Quick Start Guide

## Testing the Pipeline

1. **Basic validation**:
   ```bash
   nextflow config main.nf
   ```

2. **Test run with example data** (once you have test FASTQ files):
   ```bash
   nextflow run main.nf -profile test,docker --outdir test_results
   ```

3. **Production run**:
   ```bash
   nextflow run main.nf --input samplesheet.csv --outdir results -profile docker
   ```

## Customizing UMI Extraction

The default UMI pattern is `(?P<umi_1>.{11})CAAAAAA.*` which extracts 11 nucleotides followed by the constant sequence `CAAAAAA`. 

To customize:

```bash
nextflow run main.nf --input samplesheet.csv --bc_pattern '(?P<umi_1>.{8})TTTTTT.*' --outdir results
```

## Adding New Modules

1. **For local custom modules**:
   - Create `.nf` file in `modules/local/`
   - Follow the UMI2DEFLINE module as a template
   - Include in main.nf: `include { MODULE_NAME } from './modules/local/modulename'`

2. **For nf-core modules**:
   - Install using nf-core tools: `nf-core modules install <module_name>`
   - Or download manually to `modules/nf-core/`

## Directory Structure Details

```
modules/local/          # Your custom process definitions
modules/nf-core/        # Standard nf-core modules  
subworkflows/local/     # Custom multi-step workflows
subworkflows/nf-core/   # Standard nf-core subworkflows
workflows/              # Main workflow definitions (alternative to main.nf)
conf/                   # Configuration files
  ├── base.config       # Resource requirements
  ├── modules.config    # Module-specific options  
  └── test.config       # Test data configuration
bin/                    # Custom scripts (automatically in PATH)
assets/                 # Static files, schemas, test data
lib/                    # Custom Groovy functions
```

## Best Practices Implemented

1. **Meta maps**: Each sample carries metadata (id, barcode) through the pipeline
2. **Resource labels**: Processes tagged with resource requirements (process_medium, etc.)
3. **Configurable parameters**: UMI patterns and other settings via config
4. **Version tracking**: Software versions collected and reported
5. **Error handling**: File existence checks and proper error messages
6. **Documentation**: Comprehensive README and inline comments
7. **Testing**: Test profile for development and validation

## Next Steps

1. Add your FASTQ test files to test the pipeline
2. Customize the UMI extraction pattern for your data
3. Add additional processing modules as needed
4. Set up CI/CD for automated testing
5. Consider adding MultiQC for quality control reporting