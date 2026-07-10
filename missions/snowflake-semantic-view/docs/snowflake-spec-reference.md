# Snowflake Semantic View YAML Spec Reference

Condensed reference for the snowflake-semantic-view mission. Full spec:
https://docs.snowflake.com/en/user-guide/views-semantic/semantic-view-yaml-spec

---

## Root Document Shape

A Snowflake semantic view YAML has these top-level keys:

```yaml
name: <string>                    # REQUIRED — semantic view name
description: <string>             # Business description

tables:                           # REQUIRED — min 1 logical table
  - name: <string>
    ...

relationships: [...]              # Joins between logical tables
metrics: [...]                    # Derived (view-level) metrics
verified_queries: [...]           # Example Q&A pairs with SQL
custom_instructions: <string>     # Freeform SQL generation guidance
module_custom_instructions:       # Scoped guidance (preferred over custom_instructions)
  sql_generation: <string>
  question_categorization: <string>
tags: [...]                       # Object tags on the semantic view
```

---

## Logical Table

Each entry under `tables:` maps to a physical base table.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique logical table name |
| `description` | No | Business-friendly explanation |
| `base_table` | Yes | Physical table reference (see below) |
| `dimensions` | No | Categorical attribute columns |
| `time_dimensions` | No | Date/timestamp columns |
| `facts` | No | Row-level quantitative columns |
| `metrics` | No | Table-scoped aggregate measures |
| `filters` | No | Standalone filter expressions |
| `tags` | No | Object tags |

### `base_table`

```yaml
base_table:
  database: <database>       # REQUIRED
  schema: <schema>           # REQUIRED
  table: <base table name>   # REQUIRED
```

---

## Dimensions

Categorical attributes answering "who," "what," "where."

```yaml
dimensions:
  - name: <string>            # REQUIRED — unique within table
    expr: <sql_expression>    # REQUIRED — scalar SQL
    description: <string>
    data_type: <snowflake_type>
    synonyms: [<strings>]
    unique: <boolean>
    is_enum: <boolean>
    sample_values: [<strings>]
    labels: [filter]          # marks as WHERE clause filter (expr must be BOOLEAN)
    cortex_search_service:
      service: <string>
      literal_column: <string>
      database: <string>
      schema: <string>
    tags: [...]
```

**Rules:**
- `expr` must be a **scalar** SQL expression (no aggregates)
- If `is_enum: true`, `sample_values` is treated as the complete value set

---

## Time Dimensions

Date/timestamp columns with time-based handling.

```yaml
time_dimensions:
  - name: <string>            # REQUIRED
    expr: <sql_expression>    # REQUIRED — scalar SQL
    description: <string>
    data_type: <snowflake_type>
    synonyms: [<strings>]
    unique: <boolean>
    sample_values: [<strings>]
```

**Rules:**
- Same as dimensions but specifically for date/timestamp/time columns
- `expr` must be scalar (no aggregates)

---

## Facts

Row-level quantitative attributes ("how much," "how many").

```yaml
facts:
  - name: <string>            # REQUIRED
    expr: <sql_expression>    # REQUIRED — scalar SQL
    description: <string>
    data_type: <snowflake_type>
    synonyms: [<strings>]
    access_modifier: <public_access | private_access>  # default: public_access
    labels: [filter]          # marks as WHERE clause filter (expr must be BOOLEAN)
    tags: [...]
```

**Rules:**
- `expr` must be scalar (no aggregates)
- `private_access` hides from queries (useful for intermediate calculations)

---

## Metrics (table-level)

Aggregate measures scoped to a single logical table.

```yaml
metrics:
  - name: <string>            # REQUIRED
    expr: <sql_expression>    # REQUIRED — must contain aggregate (SUM/COUNT/AVG/MIN/MAX/etc.)
    description: <string>
    synonyms: [<strings>]
    access_modifier: <public_access | private_access>
    non_additive_dimensions:
      - table: <table_name>
        dimension: <dimension_name>
        sort_direction: <ascending | descending>
        null_order: <first | last>
    using_relationships:
      - <relationship_name>
    tags: [...]
```

**Rules:**
- `expr` MUST contain at least one aggregate function
- `non_additive_dimensions` specifies dimensions the metric cannot be aggregated across

---

## Relationships

Joins between logical tables. Defined at the view level (not inside tables).

```yaml
relationships:
  - name: <string>            # REQUIRED
    left_table: <table_name>  # REQUIRED — references a tables[].name
    right_table: <table_name> # REQUIRED — references a tables[].name
    relationship_columns:     # REQUIRED — min 1 pair
      - left_column: <column>
        right_column: <column>
```

**Rules:**
- `left_table` and `right_table` must reference existing logical table names
- Join/relationship type is automatically inferred (no `join_type` or `relationship_type`)
- Each pair maps a left column to a right column

---

## Derived Metrics (view-level)

View-level metrics combining data from multiple tables. Defined at the top level, not inside a table.

```yaml
metrics:
  - name: <string>            # REQUIRED
    expr: <sql_expression>    # REQUIRED — may reference table.metric
    description: <string>
    synonyms: [<strings>]
    access_modifier: <public_access | private_access>
    tags: [...]
```

---

## Verified Queries

Example questions with SQL answers for Cortex Analyst.

```yaml
verified_queries:
  - name: <string>            # REQUIRED — descriptive name
    question: <string>        # REQUIRED — natural language question
    sql: <string>             # REQUIRED — SQL query answering the question
    verified_at: <int>        # Optional — UNIX epoch seconds
    verified_by: <string>     # Optional — who verified
    use_as_onboarding_question: <boolean>  # Optional — show as suggestion
```

---

## Custom Instructions

Freeform guidance for Cortex Analyst SQL generation.

```yaml
custom_instructions: <string>

# OR (preferred — more granular):
module_custom_instructions:
  sql_generation: <string>
  question_categorization: <string>
```

---

## Tags

Object tags at any level (view, table, dimension, fact, metric).

```yaml
tags:
  - name:
      database: <database>
      schema: <schema>
      tag: <tag_name>
    value: <tag_value>
```

---

## Access Modifiers

Available on facts and metrics:
- `public_access` (default) — visible and queryable
- `private_access` — hidden from queries, used for intermediate calculations

---

## Filters

Two approaches:
1. **Entity-level** (preferred): add `labels: [filter]` to a dimension or fact whose `expr` resolves to BOOLEAN
2. **Standalone**: define under `filters:` at the table level

```yaml
filters:
  - name: <string>
    description: <string>
    expr: <boolean_sql_expression>
    synonyms: [<strings>]
```

---

## Valid Snowflake Data Types

Common types for `data_type` fields:
`VARCHAR`, `STRING`, `TEXT`, `NUMBER`, `INT`, `INTEGER`, `BIGINT`, `SMALLINT`,
`FLOAT`, `DOUBLE`, `DECIMAL`, `NUMERIC`, `BOOLEAN`, `DATE`, `TIMESTAMP`,
`TIMESTAMP_LTZ`, `TIMESTAMP_NTZ`, `TIMESTAMP_TZ`, `TIME`, `VARIANT`,
`OBJECT`, `ARRAY`

---

## Complete Example

```yaml
name: revenue_analysis
description: "Semantic view for analyzing revenue across products and customers"

tables:
  - name: customers
    description: "Customer information"
    base_table:
      database: sales_db
      schema: public
      table: customers
    dimensions:
      - name: customer_name
        synonyms: ["client name", "customer"]
        description: "Full name of the customer"
        expr: c_name
        data_type: VARCHAR
      - name: customer_segment
        description: "Customer market segment"
        expr: c_mktsegment
        data_type: VARCHAR
        is_enum: true

  - name: orders
    description: "Order information"
    base_table:
      database: sales_db
      schema: public
      table: orders
    time_dimensions:
      - name: order_year
        description: "Year when order was placed"
        expr: YEAR(o_orderdate)
        data_type: NUMBER
    facts:
      - name: order_total
        description: "Total order amount"
        expr: o_totalprice
        data_type: NUMBER
    metrics:
      - name: total_orders
        description: "Total number of orders"
        expr: COUNT(*)
      - name: average_order_value
        description: "Average order value"
        expr: AVG(o_totalprice)

relationships:
  - name: orders_to_customers
    left_table: orders
    right_table: customers
    relationship_columns:
      - left_column: o_custkey
        right_column: c_custkey

verified_queries:
  - name: top_customers_by_revenue
    question: "Who are the top 10 customers by revenue?"
    sql: |
      SELECT customer_name, SUM(order_total) as total_revenue
      FROM revenue_analysis
      GROUP BY customer_name
      ORDER BY total_revenue DESC
      LIMIT 10
    use_as_onboarding_question: true
```

---

## Key Differences from OSI Spec

| Concept | OSI | Snowflake |
|---------|-----|-----------|
| Container | `semantic_model[].datasets[]` | `tables[]` |
| Fields | Flat `fields[]` with `dimension.is_time` | Split: `dimensions`, `time_dimensions`, `facts` |
| Expressions | `expression.dialects[].expression` | `expr` (plain string) |
| Metrics | Model-level only | Table-level + view-level (derived) |
| Source | `source: schema.table` | `base_table: {database, schema, table}` |
| Joins | `from/to` with `from_columns/to_columns` | `left_table/right_table` with `relationship_columns[]` |
| Join type | Explicit | Automatically inferred |
| Extras | `custom_extensions`, `ai_context` | `verified_queries`, `custom_instructions`, `tags` |

---

## Validation Checklist

1. Root has `name` (string) and `tables` (non-empty array)
2. Each table has `name` and `base_table` with `database`, `schema`, `table`
3. Each dimension/time_dimension/fact has `name` and `expr`
4. Dimension/time_dimension/fact `expr` is scalar (no aggregates)
5. Each metric has `name` and `expr` containing an aggregate function
6. Relationships reference existing table names
7. `relationship_columns` has at least one `left_column`/`right_column` pair
8. `verified_queries` each have `name`, `question`, `sql`
9. `access_modifier` values are `public_access` or `private_access`
10. All names unique within their scope
11. `data_type` values are valid Snowflake types
