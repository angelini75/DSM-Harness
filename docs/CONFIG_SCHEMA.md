# User Configuration Schema Specification (`docs/CONFIG_SCHEMA.md`)

This document defines the canonical JSON schema for `01_data/profiles/user_config.json`.
Both AI assistants and human participants must adhere to this specification to avoid silent failures or unrecognized configuration parameters during the BYOD audit steps (`01_1_byod_audit.R`, `01_2_byod_audit.R`, `01_3_byod_audit.R`).

---

## 1. File Location & Precedence

* **Path**: `01_data/profiles/user_config.json`
* **Template**: `01_data/profiles/user_config.template.json`
* **Git Status**: Ignored by git (personal/dataset-specific).
* **Precedence**: When present, parameters in `user_config.json` override automatic heuristics and dictionaries in the R scripts.

---

## 2. Top-Level Keys Reference

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `input_file` | String | `null` (auto-detect) | Path to profile dataset (`.xlsx`, `.xls`, `.csv`). E.g. `"01_data/profiles/my_data.xlsx"`. |
| `skip_rows` | Integer | `0` | Number of metadata rows to skip before header row. |
| `has_units_row` | Boolean | `false` | Set to `true` if the row immediately below header contains measurement units (e.g. `cm`, `%`, `g/kg`). |
| `site_sheet` | String | `null` (auto-detect) | Name of Excel sheet containing site/profile coordinates and headers. |
| `site_key` | String | `null` (auto-detect) | Primary key column name in `site_sheet` (e.g. `"id_sitio"`, `"profile_id"`). |
| `horiz_sheet` | String | `null` (auto-detect) | *(Legacy 2-sheet mode)* Name of Excel sheet containing horizons. |
| `join_key` | String | `null` (auto-detect) | *(Legacy 2-sheet mode)* Common key column name linking `site_sheet` and `horiz_sheet`. |
| `horizon_sheets` | Array of Objects | `[]` | *(Multi-sheet mode)* Ordered list of horizon sheets to join sequentially. See §3. |
| `duplicate_action` | String | `"preserve_and_flag"` | How to treat duplicate keys: `"preserve_and_flag"`, `"average"`, or `"keep_first"`. |
| `duplicate_key_strategy` | String | `"fail"` | Policy when secondary horizon sheet has non-unique join keys: `"fail"`, `"average"`, or `"keep_first"`. Prevents many-to-many cross product explosion. |
| `allow_missing_essentials` | Boolean | `false` | If `false`, Step 1.1 strictly stops (fail-fast) if `profile_code`, `upper`, `lower`, or coordinates are missing. |
| `sand_sum` | Array of Strings | `[]` | List of sand sub-fraction column names in raw data to sum into the canonical `Sand` variable (e.g. `["Sand_VF", "Sand_F", "Sand_M", "Sand_C"]`). |
| `keep_columns` | Array of Strings | `[]` | List of additional raw column names to preserve in the final cleaned dataset without renaming or discarding (e.g. `["pH_nKCl", "CaCO3"]`). |
| `column_mapping` | Object | `{}` | Key-value dictionary: `{"Standard_DSM_Var": "Original_Column_Name"}`. See §4. |
| `om_to_soc_factor` | Numeric | `null` | Factor to derive $SOC = OM / factor$ (according to laboratory analytical method). If omitted, OM is not converted. |
| `source_crs` | Integer | `null` (auto-detect) | EPSG code of input coordinates if projected in metric coordinates (e.g. `4326` for WGS84, or local projected EPSG code). |
| `outlier_action` | String | `"flag"` | Spatial outlier policy: `"flag"`, `"exclude"`, or `"keep"`. |
| `outlier_ids` | Array of Strings | `[]` | List of `profile_code` IDs confirmed as spatial outliers. |
| `estimate_bd` | Boolean | `false` | If `true`, enables Bulk Density estimation into `BD_est` upon user confirmation of the selected model. |
| `selected_ptf` | String | `null` | Confirmed model for BD estimation: `"local_fit"` (calibrated simple parametric function when $n \ge \text{bd\_fit\_min\_n}$), `"best_published"` (lowest RMSE among published reference PTFs), or specific model: `"saini_1996"`, `"drew_1973"`, `"jeffrey_1979"`, `"grigal_1989"`, `"adams_1973"`, `"honeyset_1989"`. BD is never imputed without user confirmation. |
| `bd_fit_min_n` | Integer | `30` | Minimum number of measured BD samples required to calibrate a local simple parametric model without machine learning. |

---

## 3. Multi-Sheet Relational Joins (`horizon_sheets`)

When an Excel dataset distributes soil horizon information across multiple sheets (e.g. morphological description, chemical analyses, physical texture), use `horizon_sheets` instead of `horiz_sheet`:

```json
{
  "site_sheet": "Sitios",
  "site_key": "id_sitio",
  "horizon_sheets": [
    {
      "sheet": "Horizontes_General",
      "join_key": "id_sitio",
      "horiz_key": "id_horiz"
    },
    {
      "sheet": "Quimica",
      "join_key": "id_horiz"
    },
    {
      "sheet": "Fisica_Textura",
      "join_key": "id_horiz"
    }
  ]
}
```

* **`sheet`** (String, required): Exact name of the Excel sheet.
* **`join_key`** (String, required): Column name used to join this sheet with the accumulated table. If the foreign key name differs from the left table, specify `"left_key": "colA", "right_key": "colB"`.
* **`horiz_key`** (String, optional): Identifies the horizon-level primary key introduced by this sheet to be used in subsequent joins.

---

## 4. Standard DSM Target Variables (`column_mapping`)

The `column_mapping` object maps canonical OpenNSIS / ISO 28258 variable names to the user's raw column names:

| Standard DSM Variable | Allowed Types | Description |
| :--- | :--- | :--- |
| `profile_code` | Character / Numeric | Unique profile or pedon identifier (**Mandatory**) |
| `Horizon` | Character | Horizon designation (e.g. `A`, `Bt`, `C`) |
| `upper` | Numeric | Upper depth in cm (**Mandatory**) |
| `lower` | Numeric | Lower depth in cm (**Mandatory**) |
| `longitude` | Numeric | X coordinate (geographic or projected) (**Mandatory**) |
| `latitude` | Numeric | Y coordinate (geographic or projected) (**Mandatory**) |
| `SOC` | Numeric | Soil Organic Carbon (%) or g/kg |
| `OM` | Numeric | Organic Matter (%) |
| `pH_H2O` | Numeric | Soil pH in water |
| `Clay` | Numeric | Clay fraction (%) |
| `Sand` | Numeric | Sand fraction (%) |
| `Silt` | Numeric | Silt fraction (%) |
| `BD` | Numeric | Bulk density ($g/cm^3$) |
| `CEC` | Numeric | Cation Exchange Capacity ($cmol(+)/kg$) |
| `Total_N` | Numeric | Total Nitrogen (%) |
| `P_ext` | Numeric | Extractable Phosphorus (mg/kg or ppm) |

> [!NOTE]
> **Extensibility**: The variables listed above represent canonical diagnostic properties for Digital Soil Mapping. However, DSM-Harness does NOT restrict or prohibit extra analytical variables. Participants can freely include additional variables via `column_mapping` (e.g. `{"pH_nKCl": "PH_KCL", "CaCO3": "CARBONATOS"}`) or declaratively retain any raw columns via `"keep_columns": ["COL_A", "COL_B"]`. All preserved columns flow cleanly through all audit steps into `cleaned_profiles.csv`.

---

## 5. Complete Examples

### Example A: Single Sheet or Flat CSV
```json
{
  "input_file": "01_data/profiles/national_soil_data.csv",
  "column_mapping": {
    "profile_code": "ID_MUESTRA",
    "upper": "PROF_INI",
    "lower": "PROF_FIN",
    "longitude": "COORD_X",
    "latitude": "COORD_Y",
    "SOC": "CARBONO_ORG",
    "pH_H2O": "PH_AGUA",
    "Clay": "ARCILLA"
  },
  "keep_columns": ["pH_nKCl", "CaCO3"],
  "source_crs": 4326,
  "duplicate_action": "preserve_and_flag"
}
```

### Example B: Relational Excel (Sites + Multiple Horizon Sheets)
```json
{
  "input_file": "01_data/profiles/perfiles_nacionales.xlsx",
  "site_sheet": "SITIOS",
  "site_key": "ID_PERFIL",
  "horizon_sheets": [
    {
      "sheet": "HORIZONTES",
      "join_key": "ID_PERFIL",
      "horiz_key": "ID_HORIZONTE"
    },
    {
      "sheet": "ANALISIS_QUIMICO",
      "join_key": "ID_HORIZONTE"
    }
  ],
  "column_mapping": {
    "profile_code": "ID_PERFIL",
    "Horizon": "HORIZONTE_DESC",
    "upper": "PROF_DESDE",
    "lower": "PROF_HASTA",
    "longitude": "X_COORD",
    "latitude": "Y_COORD",
    "OM": "MATERIA_ORGANICA",
    "pH_H2O": "PH",
    "Clay": "ARCILLA_PCT",
    "Sand": "ARENA_PCT",
    "Silt": "LIMO_PCT"
  },
  "keep_columns": ["METODO_ANALISIS"],
  "om_to_soc_factor": null,
  "source_crs": 4326,
  "duplicate_action": "preserve_and_flag"
}
```
