# AGENTS (DSM-Harness v2 Runtime Index)

Welcome to **DSM-Harness v2** (FAO / SoilFER / OpenNSIS). This document defines the core principles and operational contract for AI assistants.

---

## 1. Core Principles (10 Principles)

1. **Repository Files First**: Always read project files locally in the repository (e.g., `projects/<name>/reports/*.txt`). Never search the web or external paths for them.
2. **Fixed Step Contract**: Each step reads fixed input files and writes fixed output files. Order is enforced and sequential.
3. **No In-Memory Shared State**: Steps share nothing through the R session. State is transferred solely via files on disk (`data/*.csv`, `reports/*.txt`, `config.json`).
4. **Agent Writes Config, User Confirms**: The user never edits JSON directly. The agent interviews the user, writes `config.json`, and summarizes the actions in plain language for user confirmation.
5. **No Invented Columns**: Every column in `config.json` must exist in the dataset inspected in Step 0.
6. **Transparent Auditing & Decisions**: Scripts never prompt or guess for the user. Confirmed decisions are logged automatically to `projects/<name>/decisions_log.csv`.
7. **Clean Runner Protocol**: `run_step(step, project)` executes in an isolated environment via `sys.source()`. Errors log call and traceback to `reports/<step>_error.txt` and return `invisible(FALSE)`.
8. **Bilingual Interaction**: Converse and formulate questions in the user's language (Spanish or English). Scripts and internal code documentation are written in English.
9. **Pedological Transparency**: Never silently impute or alter data. For bulk density, contrast the published PTF catalogue against local observations; impute only when explicitly requested.
10. **Code Fixes Over Prose**: Bugs and edge cases are solved in code and tests, never by bloating prompt rules.

---

## 2. Step Table

| Step | Reads | Writes | User Confirms |
| :--- | :--- | :--- | :--- |
| **0 Inspect** | `data/<raw files>` | `reports/00_inspection.txt` | Which raw file and tables/sheets to use |
| **1.1 Map** | Raw data file | `data/01_mapped.csv`, `reports/11_mapping.txt` | Base table, joins, roles, categories, duplicate key strategy |
| **1.2 Spatial** | `data/01_mapped.csv` | `data/02_spatial.csv`, `reports/12_spatial.txt` | Source CRS (from candidates); resulting lon/lat bounding box |
| **1.3 Pedological** | `data/02_spatial.csv` | `data/03_clean.csv`, `reports/13_pedological.txt` | Bulk density estimation option; exclusions |

---

## 3. Configuration Reference (`config.json`)

Stored at `projects/<name>/config.json`. Validated before each execution.

- **`project`**: Project name matching folder `projects/<name>/`. (Required)
- **`language`**: `"en"` or `"es"`. (Required)
- **`input_file`**: Path relative to project folder (e.g. `"data/profiles.xlsx"`). Never absolute. (Required)
- **`sheets`**: Array of sheet names to read (for Excel files).
- **`base_table`**: Sheet or table name defining the base rows for relational joins.
- **`joins`**: Array of declarative join objects applied sequentially to `base_table`:
  ```json
  [
    {
      "table": "profiles",
      "by": { "profile_id": "site_code" }
    },
    {
      "table": "horizons_phys",
      "by": { "profile_id": "profile_id", "layer_id": "layer_id" }
    }
  ]
  ```
- **`roles`**: Column assignments (may reference `table.column` or bare column names):
  - Required: `profile_id`, `x`, `y`, `top`, `bottom`.
  - Optional: `bulk_density`, `organic_carbon`, `organic_matter`.
- **`categories`**: Canonical column-to-category map (object mapping each column to a single category string):
  ```json
  {
    "clay": "texture",
    "sand": "texture",
    "ph": "chemistry",
    "soc": "organic matter and density"
  }
  ```
  Allowed categories: `identification`, `location`, `depth`, `texture`, `organic matter and density`, `chemistry`, `salts and conductivity`, `nutrients`, `other`.
- **`excluded_categories`**: Optional list of categories to drop.
- **`duplicate_key_strategy`**: `"fail"`, `"average"`, or `"keep_first"`.
- **`source_crs`**: Target coordinate reference system (e.g. `"EPSG:32642"` or `"EPSG:4326"`).
- **`impute_bulk_density`**: `true` or `false`. If true, estimates are written to separate column `bd_imputed`.
