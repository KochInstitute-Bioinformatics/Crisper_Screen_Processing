#!/usr/bin/env python3
"""
Annotate UMI groups with sgRNA sequence and gene information.

This script:
1. Reads umi_tools group output (TSV format)
2. Extracts contig, final_umi, final_umi_count columns
3. Removes duplicate rows
4. Annotates each row with guide sequence and gene from reference CSV
"""

import sys
import csv
import argparse
from pathlib import Path


def load_sgrna_annotations(sgrna_file):
    """
    Load sgRNA to gene mapping from CSV file.
    
    Args:
        sgrna_file: Path to CSV with columns: sg_ID,sgSeq,Repaired_Gene
        
    Returns:
        dict: {contig_id: {'sgSeq': seq, 'gene': gene}}
    """
    annotations = {}
    
    try:
        with open(sgrna_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                sg_id = row['sg_ID']
                annotations[sg_id] = {
                    'sgSeq': row['sgSeq'],
                    'gene': row['Repaired_Gene']
                }
        
        print(f"Loaded {len(annotations)} sgRNA annotations", file=sys.stderr)
        return annotations
        
    except FileNotFoundError:
        print(f"ERROR: sgRNA annotation file not found: {sgrna_file}", file=sys.stderr)
        sys.exit(1)
    except KeyError as e:
        print(f"ERROR: Missing expected column in sgRNA file: {e}", file=sys.stderr)
        sys.exit(1)


def process_groups_file(groups_file, sgrna_annotations, output_file):
    """
    Process umi_tools group output and annotate with sgRNA information.
    
    Args:
        groups_file: Path to umi_tools group output TSV
        sgrna_annotations: Dictionary of sgRNA annotations
        output_file: Path to write annotated output
    """
    seen_rows = set()
    records_processed = 0
    records_deduplicated = 0
    records_annotated = 0
    records_unannotated = 0
    
    try:
        with open(groups_file, 'r') as f_in, open(output_file, 'w', newline='') as f_out:
            reader = csv.DictReader(f_in, delimiter='\t')
            
            # Check for expected columns
            expected_cols = ['contig', 'final_umi', 'final_umi_count']
            missing_cols = [col for col in expected_cols if col not in reader.fieldnames]
            if missing_cols:
                print(f"ERROR: Missing columns in groups file: {missing_cols}", file=sys.stderr)
                print(f"Available columns: {reader.fieldnames}", file=sys.stderr)
                sys.exit(1)
            
            # Setup output writer with new columns
            output_fields = ['contig', 'final_umi', 'final_umi_count', 'sgSeq', 'gene']
            writer = csv.DictWriter(f_out, fieldnames=output_fields, delimiter='\t')
            writer.writeheader()
            
            # Process each row
            for row in reader:
                records_processed += 1
                
                # Extract key columns
                contig = row['contig']
                final_umi = row['final_umi']
                final_umi_count = row['final_umi_count']
                
                # Create tuple for deduplication
                row_key = (contig, final_umi, final_umi_count)
                
                # Skip duplicates
                if row_key in seen_rows:
                    records_deduplicated += 1
                    continue
                    
                seen_rows.add(row_key)
                
                # Annotate with sgRNA information
                if contig in sgrna_annotations:
                    sg_seq = sgrna_annotations[contig]['sgSeq']
                    gene = sgrna_annotations[contig]['gene']
                    records_annotated += 1
                else:
                    sg_seq = 'NA'
                    gene = 'NA'
                    records_unannotated += 1
                    if records_unannotated <= 10:  # Only show first 10 warnings
                        print(f"WARNING: No annotation found for contig: {contig}", file=sys.stderr)
                
                # Write annotated row
                writer.writerow({
                    'contig': contig,
                    'final_umi': final_umi,
                    'final_umi_count': final_umi_count,
                    'sgSeq': sg_seq,
                    'gene': gene
                })
        
        # Print summary statistics
        print(f"\nProcessing Summary:", file=sys.stderr)
        print(f"  Records processed: {records_processed}", file=sys.stderr)
        print(f"  Duplicates removed: {records_deduplicated}", file=sys.stderr)
        print(f"  Unique records: {len(seen_rows)}", file=sys.stderr)
        print(f"  Records annotated: {records_annotated}", file=sys.stderr)
        print(f"  Records without annotation: {records_unannotated}", file=sys.stderr)
        
    except FileNotFoundError:
        print(f"ERROR: Groups file not found: {groups_file}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR processing groups file: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description='Annotate UMI groups with sgRNA and gene information'
    )
    parser.add_argument(
        '-i', '--input',
        required=True,
        help='Input umi_tools groups.tsv file'
    )
    parser.add_argument(
        '-a', '--annotations',
        required=True,
        help='sgRNA annotations CSV file (sg_ID,sgSeq,Repaired_Gene)'
    )
    parser.add_argument(
        '-o', '--output',
        required=True,
        help='Output annotated TSV file'
    )
    
    args = parser.parse_args()
    
    # Load annotations
    sgrna_annotations = load_sgrna_annotations(args.annotations)
    
    # Process and annotate groups file
    process_groups_file(args.input, sgrna_annotations, args.output)
    
    print(f"\nAnnotated output written to: {args.output}", file=sys.stderr)


if __name__ == '__main__':
    main()
