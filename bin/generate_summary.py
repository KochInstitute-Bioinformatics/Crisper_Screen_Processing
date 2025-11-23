#!/usr/bin/env python3
"""
Generate a summary CSV file from samples.csv and FastQC outputs
Adds read1_count and read2_count columns from FastQC data
"""

import sys
import csv
import zipfile
import os
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
    if len(sys.argv) < 3:
        print("Usage: generate_summary.py <samples.csv> <fastqc_dir> <output.csv>", file=sys.stderr)
        sys.exit(1)
    
    samples_csv = sys.argv[1]
    fastqc_dir = sys.argv[2]
    output_csv = sys.argv[3]
    
    # Read the original samples.csv
    samples = []
    with open(samples_csv, 'r') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            samples.append(row)
    
    # Add new columns
    new_fieldnames = list(fieldnames) + ['read1_count', 'read2_count']
    
    # Process each sample and get read counts from FastQC
    fastqc_path = Path(fastqc_dir)
    
    for sample in samples:
        sample_id = sample['Sample']
        
        # Find the FastQC zip files for this sample
        read1_path = Path(sample['Read1'])
        read2_path = Path(sample['Read2'])
        
        # FastQC output naming: removes .gz and .fastq, adds _fastqc.zip
        read1_base = read1_path.name.replace('.fastq.gz', '').replace('.fq.gz', '').replace('.fastq', '').replace('.fq', '')
        read2_base = read2_path.name.replace('.fastq.gz', '').replace('.fq.gz', '').replace('.fastq', '').replace('.fq', '')
        
        read1_fastqc = fastqc_path / f"{read1_base}_fastqc.zip"
        read2_fastqc = fastqc_path / f"{read2_base}_fastqc.zip"
        
        # Parse FastQC outputs
        read1_count = parse_fastqc_zip(read1_fastqc) if read1_fastqc.exists() else "NA"
        read2_count = parse_fastqc_zip(read2_fastqc) if read2_fastqc.exists() else "NA"
        
        sample['read1_count'] = read1_count if read1_count is not None else "NA"
        sample['read2_count'] = read2_count if read2_count is not None else "NA"
        
        print(f"Sample {sample_id}: Read1={sample['read1_count']}, Read2={sample['read2_count']}", file=sys.stderr)
    
    # Write output CSV
    with open(output_csv, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=new_fieldnames)
        writer.writeheader()
        writer.writerows(samples)
    
    print(f"Summary CSV written to: {output_csv}", file=sys.stderr)

if __name__ == '__main__':
    main()
