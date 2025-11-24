#!/usr/bin/env python3
"""
Generate a summary CSV file from samples.csv, FastQC outputs, and deduplication logs
Adds read1_count, read2_count, umi_extracted_count, and deduplication statistics columns
"""

import sys
import csv
import zipfile
import re
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

def parse_dedup_log(log_path):
    """
    Parse umi_tools dedup log file and extract statistics
    
    Args:
        log_path: Path to dedup log file
        
    Returns:
        dict: Dictionary with keys 'dedup_input_count', 'deduped_count', 
              'positions_deduped', 'mean_umi_per_pos', 'max_umi_per_pos'
              or None values if not found
    """
    stats = {
        'dedup_input_count': None,
        'deduped_count': None,
        'positions_deduped': None,
        'mean_umi_per_pos': None,
        'max_umi_per_pos': None
    }
    
    try:
        with open(log_path, 'r') as f:
            for line in f:
                line = line.strip()
                
                # INFO Reads: Input Reads: 12345
                if 'INFO Reads: Input Reads:' in line:
                    match = re.search(r'Input Reads:\s+(\d+)', line)
                    if match:
                        stats['dedup_input_count'] = int(match.group(1))
                
                # INFO Number of reads out: 12345
                elif 'INFO Number of reads out:' in line:
                    match = re.search(r'Number of reads out:\s+(\d+)', line)
                    if match:
                        stats['deduped_count'] = int(match.group(1))
                
                # INFO Total number of positions deduplicated: 12345
                elif 'INFO Total number of positions deduplicated:' in line:
                    match = re.search(r'positions deduplicated:\s+(\d+)', line)
                    if match:
                        stats['positions_deduped'] = int(match.group(1))
                
                # INFO Mean number of unique UMIs per position: 1.23
                elif 'INFO Mean number of unique UMIs per position:' in line:
                    match = re.search(r'UMIs per position:\s+([\d.]+)', line)
                    if match:
                        stats['mean_umi_per_pos'] = float(match.group(1))
                
                # INFO Max. number of unique UMIs per position: 123
                elif 'INFO Max. number of unique UMIs per position:' in line:
                    match = re.search(r'UMIs per position:\s+(\d+)', line)
                    if match:
                        stats['max_umi_per_pos'] = int(match.group(1))
    
    except Exception as e:
        print(f"Error parsing {log_path}: {e}", file=sys.stderr)
        return stats
    
    return stats

def main():
    if len(sys.argv) < 6:
        print("Usage: generate_summary.py <samples.csv> <fastqc_raw_dir> <fastqc_umi_dir> <dedup_log_dir> <output.csv>", file=sys.stderr)
        sys.exit(1)
    
    samples_csv = sys.argv[1]
    fastqc_raw_dir = sys.argv[2]
    fastqc_umi_dir = sys.argv[3]
    dedup_log_dir = sys.argv[4]
    output_csv = sys.argv[5]
    
    # Read the original samples.csv
    samples = []
    with open(samples_csv, 'r') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        for row in reader:
            samples.append(row)
    
    # Add new columns
    new_fieldnames = list(fieldnames) + [
        'read1_count', 
        'read2_count', 
        'umi_extracted_count',
        'dedup_input_count',
        'deduped_count',
        'positions_deduped',
        'mean_umi_per_pos',
        'max_umi_per_pos'
    ]
    
    # Process each sample
    fastqc_raw_path = Path(fastqc_raw_dir)
    fastqc_umi_path = Path(fastqc_umi_dir)
    dedup_log_path = Path(dedup_log_dir)
    
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
        
        # Deduplication log file: {sample_id}_dedup.log
        dedup_log = dedup_log_path / f"{sample_id}_dedup.log"
        
        print(f"\nDEDUPLICATION STATS:", file=sys.stderr)
        print(f"  Log: {dedup_log.name} - {'✓ EXISTS' if dedup_log.exists() else '✗ NOT FOUND'}", file=sys.stderr)
        
        # Parse deduplication log
        if dedup_log.exists():
            dedup_stats = parse_dedup_log(dedup_log)
            sample['dedup_input_count'] = dedup_stats['dedup_input_count'] if dedup_stats['dedup_input_count'] is not None else "NA"
            sample['deduped_count'] = dedup_stats['deduped_count'] if dedup_stats['deduped_count'] is not None else "NA"
            sample['positions_deduped'] = dedup_stats['positions_deduped'] if dedup_stats['positions_deduped'] is not None else "NA"
            sample['mean_umi_per_pos'] = dedup_stats['mean_umi_per_pos'] if dedup_stats['mean_umi_per_pos'] is not None else "NA"
            sample['max_umi_per_pos'] = dedup_stats['max_umi_per_pos'] if dedup_stats['max_umi_per_pos'] is not None else "NA"
            
            print(f"  Input reads: {sample['dedup_input_count']}", file=sys.stderr)
            print(f"  Deduped reads: {sample['deduped_count']}", file=sys.stderr)
            print(f"  Positions deduped: {sample['positions_deduped']}", file=sys.stderr)
            print(f"  Mean UMI/pos: {sample['mean_umi_per_pos']}", file=sys.stderr)
            print(f"  Max UMI/pos: {sample['max_umi_per_pos']}", file=sys.stderr)
        else:
            sample['dedup_input_count'] = "NA"
            sample['deduped_count'] = "NA"
            sample['positions_deduped'] = "NA"
            sample['mean_umi_per_pos'] = "NA"
            sample['max_umi_per_pos'] = "NA"
            print(f"  Result: All stats = NA (file not found)", file=sys.stderr)
    
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
    