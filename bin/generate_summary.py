#!/usr/bin/env python3
"""
Generate a summary CSV file from samples.csv and FastQC outputs
Adds read1_count, read2_count, and umi_extracted_count columns from FastQC data
"""

import sys
import csv
import zipfile
from pathlib import Path

def parse_fastqc_zip(zip_path):
    """
    Parse FastQC zip file and extract Total Sequences
    
    Args:
        zip_path: Path to FastQC zip file
        
    Returns:
        int: Total number of sequences, or None if not found
    """
    try:
        with zipfile.ZipFile(zip_path, 'r') as zf:
            # Find fastqc_data.txt in the zip
            data_file = None
            for name in zf.namelist():
                if name.endswith('fastqc_data.txt'):
                    data_file = name
                    break
            
            if not data_file:
                print(f"Warning: fastqc_data.txt not found in {zip_path}", file=sys.stderr)
                return None
            
            # Read and parse the data file
            with zf.open(data_file) as f:
                for line in f:
                    line = line.decode('utf-8').strip()
                    if line.startswith('Total Sequences'):
                        # Line format: "Total Sequences\t12345"
                        parts = line.split('\t')
                        if len(parts) == 2:
                            return int(parts[1])
    except Exception as e:
        print(f"Error parsing {zip_path}: {e}", file=sys.stderr)
        return None
    
    return None

def main():
    if len(sys.argv) < 5:
        print("Usage: generate_summary.py <samples.csv> <fastqc_raw_dir> <fastqc_umi_dir> <output.csv>", file=sys.stderr)
        sys.exit(1)
    
    samples_csv = sys.argv[1]
    fastqc_raw_dir = sys.argv[2]
    fastqc_umi_dir = sys.argv[3]
    output_csv = sys.argv[4]
    
    # Read the original samples.csv
    samples = []
    with open(samples_csv, 'r') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            samples.append(row)
    
    # Add new columns
    new_fieldnames = list(fieldnames) + ['read1_count', 'read2_count', 'umi_extracted_count']
    
    # Process each sample
    fastqc_raw_path = Path(fastqc_raw_dir)
    fastqc_umi_path = Path(fastqc_umi_dir)
    
    print("=" * 60, file=sys.stderr)
    print("FASTQC SUMMARY GENERATION", file=sys.stderr)
    print("=" * 60, file=sys.stderr)
    
    for sample in samples:
        sample_id = sample['Sample']
        
        print(f"\nSample: {sample_id}", file=sys.stderr)
        print("-" * 60, file=sys.stderr)
        
        # Raw FastQC files: {sample_id}_1_fastqc.zip, {sample_id}_2_fastqc.zip
        read1_fastqc_raw = fastqc_raw_path / f"{sample_id}_1_fastqc.zip"
        read2_fastqc_raw = fastqc_raw_path / f"{sample_id}_2_fastqc.zip"
        
        print(f"RAW READS:", file=sys.stderr)
        print(f"  Read1: {read1_fastqc_raw.name} - {'✓ EXISTS' if read1_fastqc_raw.exists() else '✗ NOT FOUND'}", file=sys.stderr)
        print(f"  Read2: {read2_fastqc_raw.name} - {'✓ EXISTS' if read2_fastqc_raw.exists() else '✗ NOT FOUND'}", file=sys.stderr)
        
        # Parse raw FastQC outputs
        read1_count = parse_fastqc_zip(read1_fastqc_raw) if read1_fastqc_raw.exists() else None
        read2_count = parse_fastqc_zip(read2_fastqc_raw) if read2_fastqc_raw.exists() else None
        
        sample['read1_count'] = read1_count if read1_count is not None else "NA"
        sample['read2_count'] = read2_count if read2_count is not None else "NA"
        
        print(f"  Result: Read1={sample['read1_count']}, Read2={sample['read2_count']}", file=sys.stderr)
        
                # UMI-extracted FastQC file: {sample_id}_fastqc.zip
        # Note: FastQC renames single files using meta.id prefix (no _1 suffix for single files)
        umi_fastqc = fastqc_umi_path / f"{sample_id}_fastqc.zip"
        
        print(f"\nUMI-EXTRACTED READS:", file=sys.stderr)
        print(f"  UMI: {umi_fastqc.name} - {'✓ EXISTS' if umi_fastqc.exists() else '✗ NOT FOUND'}", file=sys.stderr)
        
        # Parse UMI FastQC output
        umi_count = parse_fastqc_zip(umi_fastqc) if umi_fastqc.exists() else None
        
        sample['umi_extracted_count'] = umi_count if umi_count is not None else "NA"
        
        print(f"  Result: UMI-extracted={sample['umi_extracted_count']}", file=sys.stderr)
    
    print("\n" + "=" * 60, file=sys.stderr)
    
    # Write output CSV
    with open(output_csv, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=new_fieldnames)
        writer.writeheader()
        writer.writerows(samples)
    
    print(f"✓ Summary CSV written to: {output_csv}", file=sys.stderr)
    print("=" * 60, file=sys.stderr)

if __name__ == '__main__':
    main()