# NER Output Post-Processing Scripts

## pivot_entities_to_columns.py

Converts NER output from JSON array format to wide format with separate columns for each entity.

### What it does:

**Input format (from Pentaho):**
```csv
document_id,source,entities_json,entity_count
1,email,"[{\"entity\":\"Sarah Johnson\",\"type\":\"PERSON\"},{\"entity\":\"Acme Corp\",\"type\":\"ORGANIZATION\"}]",2
```

**Output format (wide):**
```csv
document_id,source,entities_json,entity_count,entity_1,entity_type_1,entity_2,entity_type_2,entity_3,entity_type_3,...
1,email,"[...]",2,Sarah Johnson,PERSON,Acme Corp,ORGANIZATION,,,,...
```

### Usage:

```bash
# Basic usage - creates input_file_wide.csv
python3 pivot_entities_to_columns.py input.csv

# Specify output filename
python3 pivot_entities_to_columns.py input.csv output_wide.csv

# Example with actual file
cd /home/pentaho/LLM-PDI-Integration/workshops/workshop-04-named-entity-recognition/data
python3 ../scripts/pivot_entities_to_columns.py entities_extracted_20260228_143116.csv entities_wide.csv
```

### Features:

- Creates up to 15 entity column pairs (entity_1/entity_type_1 through entity_15/entity_type_15)
- Handles both `[...]` and `{"entities": [...]}` JSON formats
- Preserves all original columns
- Shows statistics (min/max/avg entities per document)
- Gracefully handles parsing errors

### Requirements:

```bash
pip install pandas
```

### Output Columns:

All original columns, plus:
- `entity_1` - First entity text
- `entity_type_1` - First entity type (PERSON, ORGANIZATION, etc.)
- `entity_2` - Second entity text
- `entity_type_2` - Second entity type
- ... (continues up to entity_15)

### Benefits of Wide Format:

1. **Easy Filtering**: Each entity is in its own column
2. **Excel-Friendly**: Can open directly in spreadsheets
3. **No JSON Parsing**: All data is plain text
4. **Database Ready**: Can load into SQL with fixed schema
5. **Pivot Table Compatible**: Easy analysis in Excel/Tableau

### Example:

```bash
$ python3 pivot_entities_to_columns.py entities_extracted.csv

Reading: entities_extracted.csv
Original shape: (20, 14)
Columns: document_id, source, text, llm_prompt, api_response...

Expanding entities into columns...
New shape: (20, 44)

Writing: entities_extracted_wide.csv

✓ Success! Created entities_extracted_wide.csv

Sample output columns:
  document_id, source, text, llm_prompt, api_response, result_code, response_time, entities_json...

Entity statistics:
  Min entities per doc: 6
  Max entities per doc: 12
  Avg entities per doc: 9.2
```
