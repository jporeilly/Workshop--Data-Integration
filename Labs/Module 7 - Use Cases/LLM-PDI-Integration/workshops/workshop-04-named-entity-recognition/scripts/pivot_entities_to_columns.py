#!/usr/bin/env python3
"""
Convert NER output from JSON array format to wide format with entity columns.

Input:  CSV with entities_json column containing JSON array
Output: CSV with entity_1, entity_type_1, entity_2, entity_type_2, ... columns

Usage: python3 pivot_entities_to_columns.py <input.csv> [output.csv]
"""

import pandas as pd
import json
import sys
import os

def expand_entities_to_columns(df, max_entities=15):
    """
    Expand the entities_json column into separate entity_N and entity_type_N columns.

    Args:
        df: DataFrame with 'entities_json' column
        max_entities: Maximum number of entity columns to create (default: 15)

    Returns:
        DataFrame with expanded entity columns
    """
    # Initialize entity columns
    for i in range(1, max_entities + 1):
        df[f'entity_{i}'] = ''
        df[f'entity_type_{i}'] = ''

    # Process each row
    for idx, row in df.iterrows():
        try:
            # Parse the JSON array
            entities_str = row.get('entities_json', '[]')
            if pd.isna(entities_str) or entities_str == '':
                entities_str = '[]'

            entities = json.loads(entities_str)

            # Handle both formats: {"entities": [...]} and [...]
            if isinstance(entities, dict) and 'entities' in entities:
                entities = entities['entities']

            # Populate entity columns
            for i, entity in enumerate(entities[:max_entities], 1):
                df.at[idx, f'entity_{i}'] = entity.get('entity', '')
                df.at[idx, f'entity_type_{i}'] = entity.get('type', '')

        except (json.JSONDecodeError, TypeError, AttributeError) as e:
            print(f"Warning: Could not parse entities for row {idx}: {e}")
            continue

    return df


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 pivot_entities_to_columns.py <input.csv> [output.csv]")
        print("\nExample:")
        print("  python3 pivot_entities_to_columns.py entities_extracted.csv entities_wide.csv")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else input_file.replace('.csv', '_wide.csv')

    # Check if input file exists
    if not os.path.exists(input_file):
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)

    print(f"Reading: {input_file}")
    df = pd.read_csv(input_file)

    print(f"Original shape: {df.shape}")
    print(f"Columns: {', '.join(df.columns[:5])}...")

    if 'entities_json' not in df.columns:
        print("Error: Input CSV must have 'entities_json' column")
        print(f"Available columns: {', '.join(df.columns)}")
        sys.exit(1)

    print("\nExpanding entities into columns...")
    df_wide = expand_entities_to_columns(df)

    print(f"New shape: {df_wide.shape}")

    # Reorder columns to put entity columns after the original columns
    original_cols = [col for col in df.columns if not col.startswith('entity_')]
    entity_cols = sorted([col for col in df_wide.columns if col.startswith('entity_')])
    df_wide = df_wide[original_cols + entity_cols]

    print(f"\nWriting: {output_file}")
    df_wide.to_csv(output_file, index=False)

    print(f"\n✓ Success! Created {output_file}")
    print(f"\nSample output columns:")
    print(f"  {', '.join(df_wide.columns[:8])}...")

    # Show statistics
    entity_counts = []
    for _, row in df_wide.iterrows():
        count = sum(1 for i in range(1, 16) if row.get(f'entity_{i}', '') != '')
        entity_counts.append(count)

    if entity_counts:
        print(f"\nEntity statistics:")
        print(f"  Min entities per doc: {min(entity_counts)}")
        print(f"  Max entities per doc: {max(entity_counts)}")
        print(f"  Avg entities per doc: {sum(entity_counts)/len(entity_counts):.1f}")


if __name__ == '__main__':
    main()
