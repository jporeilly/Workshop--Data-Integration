#!/usr/bin/env python3
"""
Convert NER output from JSON array format to wide format - NO DEPENDENCIES VERSION

Usage: python3 pivot_entities_simple.py <input.csv> [output.csv]
"""

import csv
import json
import sys
import os


def pivot_csv(input_file, output_file, max_entities=15):
    """Convert entities_json column to wide format with entity_N columns."""

    print(f"Reading: {input_file}")

    # Read input CSV
    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames

    if not rows:
        print("Error: Input file is empty")
        return

    print(f"Original columns: {len(fieldnames)}")
    print(f"Rows: {len(rows)}")

    # Check for entities_json column
    if 'entities_json' not in fieldnames:
        print(f"Error: 'entities_json' column not found")
        print(f"Available columns: {', '.join(fieldnames)}")
        return

    # Add entity columns to fieldnames
    entity_cols = []
    for i in range(1, max_entities + 1):
        entity_cols.append(f'entity_{i}')
        entity_cols.append(f'entity_type_{i}')

    new_fieldnames = fieldnames + entity_cols

    print(f"\nExpanding entities into {len(entity_cols)} columns...")

    # Process rows
    entity_counts = []
    for row_num, row in enumerate(rows, 1):
        # Initialize entity columns
        for col in entity_cols:
            row[col] = ''

        try:
            # Parse entities_json
            entities_str = row.get('entities_json', '[]').strip()
            if not entities_str or entities_str == '':
                entities_str = '[]'

            entities = json.loads(entities_str)

            # Handle both formats
            if isinstance(entities, dict) and 'entities' in entities:
                entities = entities['entities']

            # Count non-empty entities
            count = len([e for e in entities if e.get('entity')])
            entity_counts.append(count)

            # Populate entity columns
            for i, entity in enumerate(entities[:max_entities], 1):
                row[f'entity_{i}'] = entity.get('entity', '')
                row[f'entity_type_{i}'] = entity.get('type', '')

        except (json.JSONDecodeError, TypeError, AttributeError, KeyError) as e:
            print(f"Warning row {row_num}: Could not parse entities - {e}")
            entity_counts.append(0)

    # Write output CSV
    print(f"\nWriting: {output_file}")
    with open(output_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=new_fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"✓ Success! Created {output_file}")
    print(f"New columns: {len(new_fieldnames)}")

    # Show statistics
    if entity_counts:
        print(f"\nEntity statistics:")
        print(f"  Min entities per doc: {min(entity_counts)}")
        print(f"  Max entities per doc: {max(entity_counts)}")
        print(f"  Avg entities per doc: {sum(entity_counts)/len(entity_counts):.1f}")
        print(f"  Total entities: {sum(entity_counts)}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 pivot_entities_simple.py <input.csv> [output.csv]")
        print("\nExample:")
        print("  python3 pivot_entities_simple.py entities_extracted.csv entities_wide.csv")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else input_file.replace('.csv', '_wide.csv')

    if not os.path.exists(input_file):
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)

    pivot_csv(input_file, output_file)

    print(f"\nDone! Open {output_file} to see entity columns.")


if __name__ == '__main__':
    main()
