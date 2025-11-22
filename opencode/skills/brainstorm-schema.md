# Brainstorm Schema - Interactive Schema Design & Validation

## Description
Guide collaborative design of Pandera schemas and validation rules for new Spark datasets in the homepage_merchant_ranker_gdp project. This skill provides a structured 7-phase approach to understanding data, forming hypotheses, designing validation rules, and implementing schemas that follow project conventions.

## When to Use
Use this skill when:
- The user invokes `/brainstorm-schema <dataset_name>`
- A new dataset needs schema validation in the homepage_merchant_ranker_gdp project
- Existing schemas need to be updated or refactored
- The user asks about schema design patterns for Pandera/Spark datasets

## Command Syntax
```
/brainstorm-schema <dataset_name>
```

## Execution Flow

### Phase 1: Dataset Exploration & Context Gathering
**Goal**: Understand the data before designing schema

**You must execute these steps in order:**

1. **Request Dataset Metadata**: Ask the user to run:
   ```bash
   python explore_dataset.py <dataset_name> --end-date YYYY-MM-DD
   ```
   
   Explain: "This will generate statistical summaries of the dataset including null counts, unique values, and type information. Please share the complete output so we can design an appropriate schema."
   
   **Wait for user to provide output before proceeding.**

2. **Read Related Code**: Use the Read tool to examine (in parallel):
   - `src/python/homepage_merchant_ranker_gdp/datasets.py` - Find the dataset registration function
   - `src/python/homepage_merchant_ranker_gdp/schemas.py` - Review similar existing schemas for style patterns
   - `src/python/homepage_merchant_ranker_gdp/data_validation.py` - Check available custom validation checks
   - `src/python/homepage_merchant_ranker_gdp/sql/<corresponding>.spark.sql` - Understand the SQL query that generates this data

3. **Analyze Context**: Based on the code you read, determine:
   - What domain does this dataset belong to? (User, Restaurant, Menu/Item, Clickstream)
   - How is this dataset used? (Direct feature, intermediate aggregation, etc.)
   - What are similar existing schemas we can learn from?
   - What SQL logic generates this data? (Key for understanding expected values)

### Phase 2: Data Understanding & Hypothesis Formation
**Goal**: Form initial hypotheses about the data structure

Present to the user in a clear summary format:

1. **Summary of Findings**:
   ```
   Dataset: <name>
   Purpose: <1-2 sentences from dataset function docstring>
   Domain: <User/Restaurant/Menu/Clickstream/Other>
   Similar schemas: <list 2-3 related schemas from schemas.py>
   SQL Source: <path to .spark.sql file>
   
   Data Characteristics (from explore_dataset.py output):
   - Total rows: <count>
   - Column count: <count>
   - Key columns identified: <list important columns>
   ```

2. **Initial Observations**: For each column, create a table:
   
   | Column | Type | Nulls % | Unique | Pattern/Concern |
   |--------|------|---------|--------|-----------------|
   | user_id | string | 0% | High | UUID format, should validate |
   | order_count | long | 5% | Medium | Range 0-1000, nulls seem high |
   | ... | ... | ... | ... | ... |
   
   Highlight:
   - Detected type (UUID, indicator, numeric, string, array, boolean, date)
   - Null percentage
   - Unique value characteristics
   - Any surprising patterns or potential data quality issues

3. **Questions to Clarify**: Ask specific, data-driven questions:
   - **Business meaning**: "Column X appears to be a category with values [A, B, C]. What do these represent?"
   - **Expected cardinality**: "Should user_id be unique per row, or do we expect duplicates?"
   - **Acceptable null rates**: "Column Y has 20% nulls. Is this expected, or does it indicate a data quality issue?"
   - **Data quality requirements**: "Array column Z sometimes has empty arrays. Is this valid, or should we require at least one element?"
   - **Range expectations**: "Numeric column W ranges from -5 to 10000. Are negative values valid?"

### Phase 3: Schema Design Brainstorming
**Goal**: Collaboratively design the schema structure

**For each column, walk through this systematic checklist with the user:**

Present as: "Let's design validation rules for each column. I'll ask questions based on the data patterns we observed."

#### For ALL Column Types:
- [ ] **Nullability Decision**:
  - Question: "Should `<column>` allow nulls?"
  - If YES: "What's an acceptable null ratio? I see <X>% in the data."
    - Use `has_maximum_ratios={"nulls": <threshold>}` if we want to cap it
    - Document why nulls are acceptable
  - If NO: "Should I use `nullable=False` or add `is_not_null` check?"
    - `nullable=False`: Schema-level constraint (fails fast)
    - `is_not_null`: Custom check with better logging

#### For String Columns:
Walk through this decision tree:

1. **Special String Types**:
   ```
   Is this column:
   - A UUID? → Use `is_valid_uuid`
   - Numeric (like "123", "45.6")? → Use `is_numeric_string`
   - JSON array (like '["a","b"]')? → Use `is_valid_json_array`
   - Regular text? → Continue to constraints
   ```

2. **String Constraints**:
   - **Empty strings**: "Can `<column>` be an empty string `''`?"
     - If NO: Use `is_not_empty_string`
   - **Length limits**: "Should we enforce min/max length?"
     - Use `has_string_length={"ge": <min>, "le": <max>}`
     - Reference actual data: "I see lengths from X to Y"

3. **Value Distribution**:
   - **Categorical**: "Does `<column>` have a fixed set of values?"
     - If YES: Use `has_valid_categories={"categories": ["val1", "val2"]}`
     - List all observed values for user to confirm
   - **Placeholder values**: "I see 15% of values are 'UNK'. Is this a placeholder?"
     - If YES: Use `has_maximum_ratios={"UNK": 0.20}` to cap it

#### For Numeric Columns (Integer, Long, Double):
1. **Range Validation**:
   - Present observed range: "Values range from <min> to <max>"
   - Ask: "What's the valid business range?"
   - Use `has_numeric_range={"ge": <min>, "le": <max>}`
   - Special cases:
     - Non-negative: `"ge": 0`
     - Percentages: `"ge": 0, "le": 1` or `"ge": 0, "le": 100`
     - Scores: Define based on business logic

2. **Special Values**:
   - **Binary indicator (0/1)**:
     ```python
     has_numeric_range={"ge": 0, "le": 1},
     has_maximum_ratios={"0": 0.95, "1": 0.95}  # Ensure both values exist
     ```
   - **Zero values**: "I see X% are zero. Is this expected?"
     - If too many: `has_maximum_ratios={"0": <threshold>}`
   - **Negative values**: "Are negative values valid here?"

#### For Array Columns:
**Critical distinction**: Array can be null vs. array is empty `[]`

1. **Nullability First**:
   - "Can this array column be null?"
   - If NO: Set `nullable=False`

2. **Array Size** (for non-null arrays):
   - "Can the array be empty `[]` when not null?"
   - Ask about expected size:
     - Fixed size? `has_array_size={"ge": N, "le": N}`
     - Min size? `has_array_size={"ge": N}`
     - Max size? `has_array_size={"le": N}`
     - Range? `has_array_size={"ge": min, "le": max}`

3. **Array Elements** (when array has elements):
   - **Empty string elements**: "Can array contain empty strings `['', 'value']`?"
     - If NO: Use `has_non_empty_array_elements`
   - **Numeric strings**: "Are elements numeric strings like `['123', '456']`?"
     - If YES: Use `is_numeric_string_array`
   - **String length**: "Should element strings have min/max length?"
     - Use `has_array_elements_length={"ge": <min>, "le": <max>}`
   - **Uniqueness**: "Must elements be unique (no duplicates in array)?"
     - If YES: Use `has_unique_array_elements`

4. **Array Distribution**:
   - "What's the typical array size?" (reference data)
   - "Are very large arrays a data quality issue?"

#### For Boolean Columns:
- **Distribution Check**:
  - Show: "I see X% True, Y% False, Z% null"
  - Ask: "Does this distribution seem right?"
  - Use `has_maximum_ratios` to ensure not all one value:
    ```python
    has_maximum_ratios={"True": 0.95, "False": 0.95}
    ```

#### For Date Columns:
- **Range Validation**:
  - Show: "Dates range from <min> to <max>"
  - Ask: "What's the expected date range?"
  - Useful for detecting:
    - Future dates that shouldn't exist
    - Very old dates that indicate data issues
    - Dates outside business operational period

#### For Unique Identifiers:
- **Uniqueness Check**:
  - Ask: "Should `<column>` values be unique across all rows?"
  - If YES: Use `is_unique`
  - If NO: Ask "What's the expected duplication pattern?"
    - Example: order_id unique, but user_id can repeat

### Phase 4: Validation Rules Design
**Goal**: Translate business rules into validation checks

**Start by showing available validation checks:**

```
Available Custom Checks (from data_validation.py):

Nullability & Uniqueness:
- is_not_null: Validate no nulls with detailed logging
- is_unique: Check uniqueness with duplicate examples

Numeric Validations:
- has_numeric_range: Validate numeric ranges (ge, le)

String Validations:
- has_string_length: Validate string length (ge, le)
- is_not_empty_string: Ensure no empty strings
- is_numeric_string: Validate strings are numeric
- is_valid_uuid: Check UUID format
- is_valid_json_array: Validate JSON array strings

Array Validations:
- has_array_size: Validate array length (ge, le)
- has_non_empty_array_elements: Ensure arrays don't contain empty strings
- is_numeric_string_array: Validate all array elements are numeric
- has_array_elements_length: Validate string length of array elements
- has_unique_array_elements: Ensure no duplicate elements in arrays

Distribution & Categories:
- has_maximum_ratios: Check value/null ratio thresholds
- has_valid_categories: Validate categorical values
```

**For each validation rule, discuss:**

1. **Business Justification**: "Why is this validation important?"
   - Example: "We validate user_id is a UUID because downstream systems expect UUID format for joins"

2. **Expected Behavior**: "What does this check do with our actual data?"
   - Example: "With 5% nulls observed, we'll set max ratio to 0.10 to allow some nulls but catch if it increases"

3. **Failure Scenario**: "What does failure indicate?"
   - Example: "If `is_not_empty_string` fails, it means the SQL query produced empty strings, likely from bad joins"

**Validation Design Principles:**

- **Fail Fast**: Catch data quality issues during dataset build, not during model training
- **Be Specific**: Error messages should clearly indicate what's wrong and which rows
- **Be Realistic**: Don't over-constrain (allow reasonable variation based on actual data)
- **Document Intent**: Use docstrings and comments to explain business rules
- **Enable Logging**: Always set `log_examples=True`, `log_count=True`, or `log_details=True`

**Common Validation Patterns:**

Show examples from existing schemas:
```python
# Pattern 1: UUID identifier
user_id: T.StringType() = pa.Field(
    is_valid_uuid={
        "log_count": True,
        "error": "user_id must be valid UUID format"
    },
    nullable=False
)

# Pattern 2: Non-negative count with zero cap
order_count: T.LongType() = pa.Field(
    has_numeric_range={
        "ge": 0,
        "log_examples": True,
        "error": "order_count must be non-negative"
    },
    has_maximum_ratios={
        "0": 0.50,
        "log_details": True,
        "error": "More than 50% of users have 0 orders"
    }
)

# Pattern 3: Array with size and element constraints
cuisine_ids: T.ArrayType(T.StringType()) = pa.Field(
    has_array_size={
        "ge": 1,
        "le": 50,
        "log_examples": True,
        "error": "cuisine_ids array must have 1-50 elements"
    },
    has_non_empty_array_elements={
        "log_count": True,
        "error": "cuisine_ids array contains empty strings"
    }
)
```

### Phase 5: Schema Implementation
**Goal**: Write the complete Pandera schema class

**Generate the schema following project patterns:**

```python
class <DatasetName>Schema(pa.DataFrameModel):
    """Schema for <dataset_name> dataset.
    
    <2-3 sentence description of what this data represents and its purpose>
    
    Key characteristics:
    - <Important characteristic 1 about the data>
    - <Important characteristic 2 about usage>
    - <Important characteristic 3 about data quality expectations>
    
    Data quality validations:
    - <column_name>: <Type> - <validation summary>
    - <column_name>: <Type> - <validation summary>
    ...
    
    Example row:
        Row(
            <column1>=<example_value>,
            <column2>=<example_value>,
            <column3>=<example_value>,
            ...
        )
    
    Notes:
    - <Any special considerations>
    - <Known data quality issues to watch for>
    """
    
    <column_name>: T.<SparkType>() = pa.Field(  # type: ignore[invalid-type-form]
        <validation_check1>={
            "<param>": <value>,
            "log_examples": True,  # or log_count, log_details
            "error": "<Clear, specific error message explaining what's wrong>",
        },
        <validation_check2>={
            "<param>": <value>,
            "log_count": True,
            "error": "<Another clear error message>",
        },
        nullable=<True|False>,
        # Optional: Add comment explaining complex validation logic
    )
    
    # Repeat for each column with appropriate validations
```

**Style Guidelines** (enforced from existing schemas):

1. **Type Annotations**: 
   - Always use `T.<SparkType>()` format
   - Add `# type: ignore[invalid-type-form]` comment after each field
   - Common types: `T.StringType()`, `T.LongType()`, `T.IntegerType()`, `T.DoubleType()`, `T.BooleanType()`, `T.DateType()`, `T.ArrayType(T.StringType())`

2. **Field Parameters**: 
   - Each validation check on its own line for readability
   - Indentation: 4 spaces for field, 8 spaces for validation params
   - Order: validation checks first, then `nullable`

3. **Logging**: 
   - **Always** enable logging: `log_examples=True` or `log_count=True` or `log_details=True`
   - Choose based on what's most useful:
     - `log_examples`: Shows sample failing values (good for most cases)
     - `log_count`: Shows count of violations (good for volume issues)
     - `log_details`: Shows detailed statistics (good for distribution checks)

4. **Error Messages**: 
   - Must be clear and actionable
   - Explain WHAT is wrong (not just "validation failed")
   - Bad: "Check failed"
   - Good: "user_id must be valid UUID format"
   - Better: "user_id contains non-UUID values - check upstream data source"

5. **Documentation**: 
   - Comprehensive class docstring with:
     - Purpose and context
     - Key characteristics
     - Summary of all validations
     - Example row with realistic values
     - Notes about special considerations
   - Inline comments for complex validation logic

6. **Naming Conventions**:
   - Class name: `<DatasetName>Schema` (PascalCase)
   - Must match dataset registration name
   - Example: `user_order_features` → `UserOrderFeaturesSchema`

7. **Ordering**:
   - Order columns logically:
     - IDs first (user_id, restaurant_id, etc.)
     - Then descriptive/categorical fields
     - Then numeric metrics/counts
     - Then arrays/complex types
     - Then dates/timestamps

**Full Example** (show a complete, realistic schema):

```python
class UserOrderFeaturesSchema(pa.DataFrameModel):
    """Schema for user_order_features dataset.
    
    Contains aggregated user order history features including order counts,
    monetary values, and temporal patterns for personalization models.
    
    Key characteristics:
    - One row per user (user_id is unique)
    - Covers 180-day historical window
    - All monetary values in USD cents
    - Null arrays indicate no order history
    
    Data quality validations:
    - user_id: String - Valid UUID, not null, unique
    - total_orders: Long - Non-negative, max 50% zeros
    - order_value_cents: Long - Non-negative
    - favorite_cuisines: Array[String] - 1-20 elements when not null, no empty strings
    - last_order_date: Date - Within last 180 days
    
    Example row:
        Row(
            user_id='550e8400-e29b-41d4-a716-446655440000',
            total_orders=25,
            order_value_cents=125000,
            favorite_cuisines=['italian', 'mexican', 'chinese'],
            last_order_date=datetime.date(2025, 11, 15)
        )
    
    Notes:
    - Users with no orders will have total_orders=0 and null arrays
    - Date range validated to catch stale data issues
    """
    
    user_id: T.StringType() = pa.Field(  # type: ignore[invalid-type-form]
        is_valid_uuid={
            "log_count": True,
            "error": "user_id must be valid UUID format",
        },
        is_unique={
            "log_examples": True,
            "error": "user_id must be unique - found duplicate users",
        },
        nullable=False,
    )
    
    total_orders: T.LongType() = pa.Field(  # type: ignore[invalid-type-form]
        has_numeric_range={
            "ge": 0,
            "log_examples": True,
            "error": "total_orders must be non-negative",
        },
        has_maximum_ratios={
            "0": 0.50,
            "log_details": True,
            "error": "More than 50% of users have 0 orders - check date range",
        },
        nullable=False,
    )
    
    order_value_cents: T.LongType() = pa.Field(  # type: ignore[invalid-type-form]
        has_numeric_range={
            "ge": 0,
            "log_examples": True,
            "error": "order_value_cents must be non-negative",
        },
        nullable=False,
    )
    
    favorite_cuisines: T.ArrayType(T.StringType()) = pa.Field(  # type: ignore[invalid-type-form]
        has_array_size={
            "ge": 1,
            "le": 20,
            "log_examples": True,
            "error": "favorite_cuisines must have 1-20 elements when not null",
        },
        has_non_empty_array_elements={
            "log_count": True,
            "error": "favorite_cuisines contains empty strings",
        },
        nullable=True,  # Null indicates no cuisine data available
    )
    
    last_order_date: T.DateType() = pa.Field(  # type: ignore[invalid-type-form]
        # Date range check to catch stale data
        # Note: Would need custom check for dynamic date range validation
        nullable=True,  # Null when total_orders=0
    )
```

### Phase 6: Review & Refinement
**Goal**: Ensure schema is complete and correct

**Present this checklist and verify each item:**

- [ ] **Completeness**: All columns from explore_dataset.py are included
- [ ] **Logging**: All validations have logging enabled (log_examples, log_count, or log_details)
- [ ] **Documentation**: Comprehensive docstring with example data
- [ ] **Error Messages**: Clear and actionable for each validation
- [ ] **Constraints**: Match actual data from explore_dataset.py (not over-constrained)
- [ ] **Naming**: Follows PascalCase convention and matches dataset name
- [ ] **Type Safety**: All fields have `# type: ignore[invalid-type-form]` comment
- [ ] **Nullability**: Explicitly set for each column

**Compare with similar schemas:**

Present a side-by-side comparison:

```
Similar Schema: UserBasicInfoSchema
Common patterns we should follow:
✓ UUID validation for user_id
✓ Non-negative range for counts
✓ Maximum ratio checks for zero values

Differences to note:
- UserBasicInfoSchema uses is_not_null check (more verbose logging)
- Our schema uses nullable=False (simpler, fails faster)
- Decision: Use nullable=False for consistency with newer schemas

New patterns we're introducing:
- Array size validation with ge/le
- has_non_empty_array_elements for string arrays
- Justification: Required for array columns not present in similar schemas
```

**Ask for final review:**
1. "Does this schema accurately represent the business requirements?"
2. "Are the validation constraints realistic given the data we observed?"
3. "Should any validations be stricter or more lenient?"
4. "Are the error messages clear enough for debugging?"

### Phase 7: Integration & Testing
**Goal**: Integrate schema into the codebase and validate it works

**Step 1: Add to schemas.py**

Show exactly where to insert:
```python
# In src/python/homepage_merchant_ranker_gdp/schemas.py
# Add after similar schema (e.g., after UserOrderHistorySchema if it's a user dataset)

class <NewDatasetName>Schema(pa.DataFrameModel):
    """Schema for <dataset_name> dataset.
    ...
    """
    # ... full schema code ...
```

**Step 2: Update datasets.py**

Show the exact change needed:
```python
# In src/python/homepage_merchant_ranker_gdp/datasets.py
# Find the dataset registration function:

@dataset(
    dataset_id="<dataset_name>",
    backend="spark",
    validations=<NewSchemaName>,  # ADD THIS LINE
)
def <dataset_name>(
    spark: SparkSession,
    ...
) -> DataFrame:
    ...
```

**Step 3: Testing Plan**

Provide testing commands:

```bash
# Test 1: Validate schema syntax
python -c "from homepage_merchant_ranker_gdp.schemas import <NewSchemaName>; print(<NewSchemaName>)"

# Test 2: Run validation on actual data
python -c "
from homepage_merchant_ranker_gdp import datasets, models
from gh.mlops import api

# Build dataset with validation enabled
ds = api.build_dataset(
    'homepage_merchant_ranker', 
    '<dataset_name>',
    overrides={'end_date': '2025-11-21'},  # Use recent date
    backend='spark',
    validate=True  # This triggers Pandera validation
)

print(f'✓ Validation passed! Dataset has {ds.count()} rows')
"

# Test 3: Check validation catches bad data (if possible)
# Manually inject bad data to ensure validation fails appropriately
```

**Step 4: Expected Outcomes**

Explain what to expect:
```
If validation PASSES:
✓ No exceptions raised
✓ Dataset builds successfully
✓ Console shows validation check results (due to logging enabled)
✓ Ready to use in model training

If validation FAILS:
✗ Pandera raises SchemaError
✗ Error message shows which column/check failed
✗ Log output shows example failing values (due to log_examples=True)
✗ Action: Investigate data quality issue or adjust validation constraints
```

**Step 5: Documentation Update**

Suggest documenting the new schema:
```markdown
# Add to project documentation or CHANGELOG

## Schema: <NewDatasetName>Schema
- **Dataset**: <dataset_name>
- **Purpose**: <brief description>
- **Key Validations**: <list main validations>
- **Added**: 2025-11-21
- **Notes**: <any special considerations>
```

**Step 6: Commit the Changes**

Suggest commit message:
```
feat: add Pandera schema validation for <dataset_name>

- Add <NewSchemaName> to schemas.py with comprehensive validation rules
- Enable validation in datasets.py for <dataset_name>
- Validates: <list key validations>
- Catches: <list key data quality issues>

Tested with end_date=2025-11-21, validation passes.
```

## Key Principles

### 1. Always Ask Before Assuming
- If the data shows 5% nulls but you're unsure if that's expected, **ASK the user**
- Never assume business rules - validate your understanding
- Example questions:
  - "Is 20% null rate normal for this column, or does it indicate a data quality issue?"
  - "Should user_id be unique, or can users appear multiple times?"
  - "Are negative values valid here, or do they indicate an error?"

### 2. Use Actual Data to Inform Decisions
- Always reference specific statistics from explore_dataset.py output
- Example: "I see order_count ranges from 0 to 1500 with 5% nulls. Based on this, I suggest..."
- Don't design validation rules in a vacuum - ground them in observed data

### 3. Explain Tradeoffs
When multiple validation approaches are possible, explain pros/cons:

**Example: Nullability Validation**
```
Option 1: nullable=False
  Pros: Fails fast, simple, clear intent
  Cons: Less verbose error messages, no logging of how many nulls
  
Option 2: is_not_null check
  Pros: Better logging (shows count/examples), more detailed errors
  Cons: More verbose, validation happens after schema check
  
Recommendation: Use nullable=False for new schemas (simpler, consistent with modern patterns)
```

**Example: Array Empty Elements**
```
Option 1: has_non_empty_array_elements
  Pros: Catches empty strings in arrays
  Cons: Only works when array is not null
  
Option 2: has_array_size with ge=1
  Pros: Ensures array has elements
  Cons: Doesn't catch arrays with just empty strings like ['', '']
  
Recommendation: Use both if you need to ensure arrays have meaningful content
```

### 4. Provide Context from Similar Schemas
- Always show how similar columns are validated in existing schemas
- Maintain consistency across the codebase
- Example:
  ```
  "I see UserBasicInfoSchema validates user_id with is_valid_uuid.
   Let's use the same approach for consistency."
  ```

### 5. Think About Failure Scenarios
For each validation, discuss:
1. **What does it mean if this check fails?**
   - Example: "If is_valid_uuid fails, it means the SQL query produced non-UUID strings"
2. **What action should be taken?**
   - Example: "Check the SQL join logic - likely missing COALESCE or incorrect join key"
3. **Is this a blocking issue or a warning?**
   - All Pandera validations are blocking (fail the build)
   - Justify why each validation is strict enough to block

### 6. Progressive Validation Design
Start lenient, then tighten:
1. **First iteration**: Basic type and nullability checks
2. **After initial testing**: Add range and distribution checks
3. **After production use**: Add stricter constraints based on observed issues

Don't over-constrain on first try - allow room for edge cases.

### 7. Logging Strategy
Choose logging type based on what's most useful for debugging:
- **log_examples=True**: Best for seeing actual failing values (most common)
- **log_count=True**: Best for volume issues (counting violations)
- **log_details=True**: Best for distribution checks (seeing statistics)

Always enable one of these - validation without logging is debugging in the dark.

## Common Pitfalls to Avoid

### 1. Over-constraining
**Bad**: Setting `has_numeric_range={"ge": 10, "le": 100}` when data shows 0-1000
**Good**: Use observed data range, or justify why constraint is stricter

### 2. Under-constraining
**Bad**: No validation on UUID column just because it's "string"
**Good**: Add `is_valid_uuid` to catch data quality issues early

### 3. Missing nullable handling
**Bad**: Not setting `nullable` explicitly
**Good**: Explicitly set `nullable=True` or `nullable=False` for every column

### 4. Poor error messages
**Bad**: `error="Check failed"`
**Good**: `error="user_id must be valid UUID format - found non-UUID values"`

### 5. No logging
**Bad**: Validation check without `log_examples`, `log_count`, or `log_details`
**Good**: Always enable logging to help with debugging

### 6. Ignoring array nullability vs empty arrays
**Bad**: Treating `null` and `[]` the same way
**Good**: Explicitly handle both cases:
```python
favorite_cuisines: T.ArrayType(T.StringType()) = pa.Field(
    nullable=True,  # Can be null
    has_array_size={"ge": 1},  # But if not null, must have elements
)
```

### 7. Not testing the schema
**Bad**: Adding schema and assuming it works
**Good**: Run validation on actual data to verify it passes

## Output Format

Throughout the conversation:
- Use clear headers for each phase
- Format code blocks with proper syntax highlighting
- Use tables for comparing options or showing data summaries
- Use checklists for tracking progress
- Quote actual data values when discussing constraints
- Highlight important decisions or tradeoffs

## Success Criteria

The schema design is complete when:
1. ✅ All columns from the dataset are covered
2. ✅ Each validation rule is justified with business context
3. ✅ Error messages are clear and actionable
4. ✅ Logging is enabled for all checks
5. ✅ User confirms the schema matches requirements
6. ✅ Schema is integrated into schemas.py and datasets.py
7. ✅ Testing plan is provided and executed
8. ✅ Documentation is updated

## Reference Materials

### Available Validation Checks
Always refer to `src/python/homepage_merchant_ranker_gdp/data_validation.py` for:
- Complete list of custom checks
- Parameter signatures
- Usage examples

### Existing Schemas
Reference `src/python/homepage_merchant_ranker_gdp/schemas.py` for:
- Style patterns
- Similar column validations
- Naming conventions
- Documentation patterns

### Dataset Context
Reference `src/python/homepage_merchant_ranker_gdp/datasets.py` for:
- Dataset purpose and usage
- SQL source files
- Related datasets

### SQL Queries
Reference `src/python/homepage_merchant_ranker_gdp/sql/*.spark.sql` for:
- Understanding data generation logic
- Expected value ranges
- Join patterns that affect nullability
