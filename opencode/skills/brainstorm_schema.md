# brainstorm-schema - Interactive Schema Design & Validation Command

## When to use this skill
Use this skill when the user invokes `/brainstorm-schema <dataset_name>` or mentions creating/designing a Pandera schema for a Spark dataset in the homepage_merchant_ranker_gdp project.

## Context
This skill is specific to the homepage_merchant_ranker_gdp project which uses:
- Pandera for DataFrame schema validation
- PySpark for data processing
- Custom validation checks in `data_validation.py`
- Dataset registration in `datasets.py`
- Schema definitions in `schemas.py`
- SQL queries in `sql/*.spark.sql`

## Command Flow

### Phase 1: Dataset Exploration & Context Gathering
**Goal**: Understand the data before designing schema

**Execute these steps in order:**

1. **Request Dataset Metadata**:
   - Ask the user to run:
     ```bash
     python explore_dataset.py <dataset_name> --end-date YYYY-MM-DD
     ```
   - Explicitly state: "Please provide the complete output from this command before we proceed."
   - **WAIT for user response** - do not proceed to next steps until output is provided
   - This output contains critical statistics about:
     - Column types (numeric, string, array, boolean, date, UUID, indicator)
     - Null percentages
     - Value distributions
     - String lengths
     - Array sizes
     - Sample values

2. **Read Related Code** (only after receiving explore_dataset.py output):
   Use the Read tool to examine:
   - `src/python/homepage_merchant_ranker_gdp/datasets.py` - Find the dataset registration function
   - `src/python/homepage_merchant_ranker_gdp/schemas.py` - Review similar schemas for patterns
   - `src/python/homepage_merchant_ranker_gdp/data_validation.py` - Check available custom checks
   - `src/python/homepage_merchant_ranker_gdp/sql/<corresponding>.spark.sql` - Understand the SQL query
   
3. **Analyze Context**:
   - Determine dataset domain (User, Restaurant, Menu/Item, Clickstream)
   - Understand how dataset is used (direct feature, intermediate aggregation, etc.)
   - Identify 2-3 similar existing schemas to learn from

### Phase 2: Data Understanding & Hypothesis Formation
**Goal**: Form initial hypotheses about data structure

**Present to user:**

1. **Summary of Findings**:
   ```
   Dataset: <name>
   Purpose: <1-2 sentences from dataset function>
   Domain: <User/Restaurant/Menu/Clickstream>
   Similar schemas: <list 2-3 related schemas>
   
   Data Characteristics (from explore_dataset.py output):
   - Total rows: <count>
   - Column count: <count>
   - Key columns identified: <list>
   ```

2. **Initial Observations**: For each column, note:
   - Detected type (UUID, indicator, numeric, string, array, boolean, date)
   - Null percentage
   - Unique value characteristics
   - Surprising patterns or potential data quality issues

3. **Clarifying Questions**: Ask specific questions about:
   - Business meaning of ambiguous columns
   - Expected cardinality (should IDs be unique? How many duplicates expected?)
   - Acceptable null rates (is 20% nulls expected or concerning?)
   - Data quality requirements (must all arrays have elements? Can strings be empty?)

### Phase 3: Schema Design Brainstorming
**Goal**: Collaboratively design schema structure

**For each column, walk through relevant checklist items:**

#### For ALL Column Types:
- [ ] **Nullability**: Should this be `nullable=True`?
  - If nullable, what's acceptable null ratio? (use `has_maximum_ratios`)
  - Should we use `is_not_null` for explicit validation?

#### For String Columns:
- [ ] **Special String Types**:
  - UUID? → Use `is_valid_uuid`
  - Numeric? → Use `is_numeric_string`
  - JSON? → Use `is_valid_json_array`
  
- [ ] **String Constraints**:
  - Can be empty? → Use `is_not_empty_string` if not
  - Length limits? → Use `has_string_length` with `ge`/`le`
  
- [ ] **Value Distribution**:
  - Categorical? → Use `has_valid_categories`
  - Placeholder value (e.g., 'UNK')? → Use `has_maximum_ratios`

#### For Numeric Columns (Integer, Long, Double):
- [ ] **Range Validation**:
  - Valid range? → Use `has_numeric_range` with `ge`/`le`
  
- [ ] **Special Values**:
  - Binary indicator (0/1)? → Validate with `has_numeric_range` + `has_maximum_ratios`
  - Can be zero? If so, what percentage? → Use `has_maximum_ratios`

#### For Array Columns:
- [ ] **Array Size**:
  - Fixed size? → Use `has_array_size` with `ge == le`
  - Min/max size? → Use `has_array_size` with range
  
- [ ] **Array Elements**:
  - Can array be empty when non-null? (Important distinction!)
  - Can elements be empty strings? → Use `has_non_empty_array_elements`
  - Elements numeric strings? → Use `is_numeric_string_array`
  - String length constraints? → Use `has_array_elements_length`
  - Must elements be unique? → Use `has_unique_array_elements`

#### For Boolean Columns:
- [ ] **Distribution Check**:
  - Expected ratio of True/False?
  - Use `has_maximum_ratios` to ensure not all one value

#### For Date Columns:
- [ ] **Range Validation**:
  - Expected date range for detecting data issues?

#### For Unique Identifiers:
- [ ] **Uniqueness**:
  - Should values be unique? → Use `is_unique`

### Phase 4: Validation Rules Design
**Goal**: Translate business rules into validation checks

**Reference custom validation checks** (from data_validation.py):
```
Available Custom Checks:
- is_not_null: Validate no nulls with detailed logging
- is_unique: Check uniqueness with duplicate examples
- has_numeric_range: Validate numeric ranges (ge, le)
- has_string_length: Validate string length (ge, le)
- is_not_empty_string: Ensure no empty strings
- is_numeric_string: Validate strings are numeric
- is_valid_uuid: Check UUID format
- is_valid_json_array: Validate JSON array strings
- has_array_size: Validate array length (ge, le)
- has_non_empty_array_elements: Ensure arrays don't contain empty strings
- is_numeric_string_array: Validate all array elements are numeric
- has_array_elements_length: Validate string length of array elements
- has_unique_array_elements: Ensure no duplicate elements in arrays
- has_maximum_ratios: Check value/null ratio thresholds
- has_valid_categories: Validate categorical values
- has_valid_placeholder: Check placeholder values only in single-element arrays
```

**For each validation:**
1. Explain WHY this validation is important (business context)
2. Show expected behavior with actual data from explore_dataset.py
3. Discuss what happens if validation fails

**Validation Design Principles:**
- **Fail Fast**: Catch data quality issues early
- **Be Specific**: Clear error messages indicating what's wrong
- **Be Realistic**: Don't over-constrain (allow reasonable variation)
- **Document Intent**: Use docstrings to explain business rules

### Phase 5: Schema Implementation
**Goal**: Write complete Pandera schema class

**Generate schema following project patterns:**

```python
class <DatasetName>Schema(pa.DataFrameModel):
    """Schema for <dataset_name> dataset.
    
    <2-3 sentence description of what this data represents>
    
    Key characteristics:
    - <Important characteristic 1>
    - <Important characteristic 2>
    - <Important characteristic 3>
    
    Validates:
    - <column_name>: <Type> (<validation summary>)
    - <column_name>: <Type> (<validation summary>)
    ...
    
    Example data:
        Row(<column1>=<example_value>,
            <column2>=<example_value>,
            ...)
    """
    
    <column_name>: T.<SparkType>() = pa.Field(  # type: ignore[invalid-type-form]
        <validation_check1>={
            "<param>": <value>,
            "log_examples": True,
            "error": "<clear error message>",
        },
        <validation_check2>={...},
    )
    # Repeat for each column
```

**Style Guidelines** (from existing schemas):
1. **Type Annotations**: Always use `T.<Type>()` with `# type: ignore[invalid-type-form]`
2. **Field Parameters**: Each validation check on its own line
3. **Logging**: Always set `log_examples=True` or `log_count=True` or `log_details=True`
4. **Error Messages**: Provide clear, specific error messages
5. **Documentation**: Include comprehensive docstring with examples
6. **Comments**: Add inline comments for complex validation logic

### Phase 6: Review & Refinement
**Goal**: Ensure schema is complete and correct

**Checklist:**
- [ ] All columns from dataset included
- [ ] All validations have logging enabled
- [ ] Docstring comprehensive with example data
- [ ] Error messages clear and actionable
- [ ] Validation constraints match actual data from explore_dataset.py
- [ ] Schema follows project naming conventions (e.g., `ExtractedRestaurantSchema`, `UserFeaturesSchema`)
- [ ] Similar schemas referenced for consistency

**Compare with similar schemas:**
- Show 2-3 similar schemas side-by-side
- Highlight any inconsistencies in validation approach
- Ensure new schema follows established patterns

### Phase 7: Integration & Testing
**Goal**: Integrate schema into codebase

1. **Add to schemas.py**: 
   - Show exactly where to insert new schema class
   - Follow the domain organization (Menu/Item, Clickstream, User, Restaurant)
   - Add appropriate section comment if creating new domain

2. **Add to datasets.py**: 
   - Show how to add `validations=<SchemaName>` to the dataset registration decorator
   - Import the schema at the top of the file

3. **Suggest Testing**: Recommend running:
   ```bash
   # Test the schema validation
   python -c "from homepage_merchant_ranker_gdp import datasets, models; \
              from gh.mlops import api; \
              ds = api.build_dataset('homepage_merchant_ranker', '<dataset_name>', \
                                     overrides={'end_date': 'YYYY-MM-DD'}, \
                                     backend='spark', validate=True)"
   ```

## Key Principles

### 1. Always Ask Before Assuming
If data shows 5% nulls but you're unsure if expected, **ASK** the user.

### 2. Use Actual Data to Inform Decisions
Reference specific statistics from explore_dataset.py output when discussing constraints.
Example: "The data shows 0.5% nulls - is this acceptable or should we enforce stricter validation?"

### 3. Explain Tradeoffs
When multiple validation approaches possible, explain pros/cons:
- **Strict validation** catches more issues but may break on edge cases
- **Lenient validation** more robust but may miss data quality problems

### 4. Provide Context from Similar Schemas
Show how similar columns validated in existing schemas to maintain consistency.
Example: "In UserOrderItemsSchema, `cust_id` is validated as a non-null numeric string. Should we follow the same pattern here?"

### 5. Think About Failure Scenarios
For each validation, discuss: "What does it mean if this check fails? What action should be taken?"

## Example Usage Flow

```
User: /brainstorm-schema source_merchant_performance