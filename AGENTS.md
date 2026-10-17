# AGENTS (DSM-Harness v2 Runtime Index)

Welcome to **DSM-Harness v2** (FAO / SoilFER / OpenNSIS). This document defines the core principles and operational contract for AI assistants.

---

## 1. Core Principles (10 Principles)

1. **Repository Files First**: Always read project files locally in the repository (e.g., `projects/<name>/reports/*.txt`). Never search the web or external paths for them.
2. **Fixed Files, No Shared State**: Each step reads fixed input files and writes fixed output files, in order. Steps share nothing through the R session; state lives only in files (`data/*.csv`, `reports/*.txt`, `config.json`).
3. **Evidence and Neutral Options**: State only what a report or the user has established; if something was not computed, say so. When the user must choose (CRS, duplicates, bulk density, targets), list the options with their consequences, without recommending or ranking them. Ask for facts the reports do not contain, such as the study area, instead of inferring them from the data. You may suggest values for facts only the user can confirm (for example a code), labelled as suggestions; write nothing to `config.json` until the user confirms.
4. **Agent Writes Config, User Confirms**: The user never edits JSON directly. The agent interviews the user, writes `config.json`, and summarizes the actions in plain language for user confirmation.
5. **No Invented Columns**: Every column in `config.json` must exist in the dataset inspected in Step 0.
6. **Transparent Auditing & Decisions**: Scripts never prompt or guess for the user. Confirmed decisions are logged automatically to `projects/<name>/decisions_log.csv`.
7. **Clean Runner Protocol**: `run_step(step, project)` executes in an isolated environment via `sys.source()`. Errors log call and traceback to `reports/<step>_error.txt` and return `invisible(FALSE)`.
8. **User's Language**: Use the user's language (Spanish or English). Confirm it in the first turn and create the project with `new_project("<name>", language = "<es|en>")`. Scripts and code documentation are in English.
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
| **2 Covariates** | `data/03_clean.csv`, `covariates/*.tif` | `data/04_cov_<prop>_<d1>_<d2>.csv`, `reports/20_covariates_<prop>_<d1>_<d2>.txt` | Target properties and depth intervals |
| **3 Model** | `data/04_cov_*.csv` | `outputs/models/<prop>_<d1>_<d2>.rds`, `metrics_<prop>_<d1>_<d2>.json`, `reports/30_modelling_<prop>_<d1>_<d2>.txt` | None; reviews metrics. Runner options: `targets = c(...)`, `refit = TRUE\|FALSE` |
| **3b Resources** | models, rasters, user machine (`cores`, `ram_gb`) | `reports/3b_resources.txt` | User supplies `cores` and `ram_gb` (the agent asks for them); number of vertical tiles (`cols`) |
| **4 Predict** | models, `covariates/*.tif` | `outputs/maps/<CC>-<PROJ>-<PROP>-<d1>-<d2>-mean.tif`, `sd.tif`, `reports/40_prediction_<prop>_<d1>_<d2>.txt` | Tile scheme (`tiles: {cols, rows}` with `rows: 1`), `country_code`, `project_code`. Runner options: `targets = c(...)`, `refit = TRUE\|FALSE` |
| **5 Report** | `data/04_cov_*.csv`, models, maps | `reports/report_<prop>_<d1>_<d2>.html`, `reports/50_report_<prop>_<d1>_<d2>.txt` | None; reviews HTML report. Runner options: `targets = c(...)`, `refit = TRUE\|FALSE` |

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
- **`excluded_columns`**: Optional list of column names to drop.
- **`duplicate_key_strategy`**: `"fail"`, `"average"`, or `"keep_first"`.
- **`source_crs`**: Target coordinate reference system (e.g. `"EPSG:32642"` or `"EPSG:4326"`).
- **`impute_bulk_density`**: `true` or `false`. If true, estimates are written to separate column `bd_imputed`.
- **`targets`**: Array of target objects defining property and depth intervals:
  ```json
  [
    { "property": "clay", "d1": 0, "d2": 30, "enabled": true },
    { "property": "clay", "d1": 30, "d2": 60, "enabled": true },
    { "property": "soc", "d1": 0, "d2": 30, "enabled": false }
  ]
  ```
  Each target specifies `property`, `d1` (top depth), `d2` (bottom depth, strictly $d1 < d2$), optional `enabled` (boolean, default `true`), and `code` (string of alphanumeric characters and underscores, required at the start of Steps 4 and 5 for OpenNSIS raster filenames, used as typed with no defaults). Disabled targets are skipped during Step 3 unless explicitly requested via `run_step("3", targets = c(...))`.
- **`boruta_max_runs`**: Maximum iterations for Boruta feature selection (integer, default 100).
- **`min_support`**: Minimum profile support thickness in cm for depth standardisation (numeric, default 5).
- **`refit`**: Global default flag (`true` or `false`, default `false`) indicating whether existing models should be retrained and overwritten in Step 3. Can be overridden per run via `run_step("3", refit = TRUE)`.
- **`cv_folds`**: Number of cross-validation folds for model tuning in Step 3 (integer, default 5).
- **`cv_repeats`**: Number of cross-validation repeats for Repeated CV in Step 3 (integer, default 5).
- **`cores`**: Number of CPU worker threads allocated for Steps 3 and 4 (integer >= 1). The user supplies `cores`, so the agent asks for it.
- **`ram_gb`**: RAM in GB available for spatial tiling calculations in Step 3b (numeric > 0). The user supplies `ram_gb`, so the agent asks for it.
- **`ram_share`**: Optional fraction of `ram_gb` allocated per tile in Step 3b (numeric with 0 < ram_share <= 1, default 0.25).
- **`tiles`**: User-confirmed spatial tiling grid configuration for Step 4 prediction (object with positive integer `cols` and strictly `rows: 1`, matching scheme confirmed from `reports/3b_resources.txt`).
- **`country_code`**: ISO 3166-1 alpha-3 code required for standard OpenNSIS raster product filenames in Step 4.
- **`project_code`**: Project acronym required for standard OpenNSIS raster product filenames in Step 4.


