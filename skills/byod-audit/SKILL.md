---
name: byod-audit
description: Rapid diagnostic audit, column confirmation, and cleaning procedure for national soil profile datasets (BYOD) in Excel or CSV.
---

# Skill: BYOD National Soil Data Audit & Harmonization

This skill guides the participant through the exploratory data analysis, column identification, spatial validation, depth interval verification, and pedological sanity checks of their national dataset (in `.xlsx`, `.xls` or `.csv`).

---

## 0. Fundamental Directives: Scope & Incremental Interaction

> **CRITICAL DIRECTIVES**: 
> 1. **No Terminal Execution**: The AI assistant MUST NEVER execute R scripts, run `Rscript`, or attempt to process the student's data via background terminal commands.  
> 2. **File Generation in IDE Mode (Antigravity)**: Create or update the R script directly at `02_scripts/01_byod_audit.R`. The student will open and run it inside their own RStudio session. In Web Chat mode, provide the code block in the chat.
> 3. **Strict Data Scope**: The harness is designed ONLY for the digital soil mapping (DSM) and soil spectroscopy (DRS) workflow. It is NOT an exhaustive database for all soil survey attributes. Retain ONLY core DSM columns (`profile_code`, `Horizon`, `upper`, `lower`, `longitude`, `latitude`, and target properties `SOC`/`OM`, `pH_H2O`, `Clay`, `Sand`, `Silt`, `BD`, `CEC`). **Discard all extraneous survey columns** (taxonomic classification, field morphology, survey date, land use, geology, etc.).
> 4. **Incremental Validation by Criteria (Never Monolithic)**: Do NOT generate a long monolithic script that attempts to do everything at once. Divide Stage 1 into bite-sized, testable criteria and **WAIT for student confirmation** after each step.
> 5. **Anti-Overfitting & Generalization**: Do NOT inspect, read, or overfit to private test files. Use general domain logic, alias dictionaries, and ISO 28258 / OpenNSIS standards.

---

## 1. Column Intuition Dictionary (Multilingual Aliases)

When analyzing a national dataset (Excel `.xlsx` via `readxl` or CSV via `readr`), automatically infer and propose mappings to the standard **OpenNSIS / ISO 28258** attributes:

| Target Standard Column | Common Spanish / Regional Aliases | Common English / Global Aliases |
| :--- | :--- | :--- |
| **`longitude`** | `lon`, `long`, `longitud`, `x`, `coord_x`, `long_wgs84` | `lon`, `long`, `x`, `coord_x`, `dec_long`, `wgs84_x` |
| **`latitude`** | `lat`, `latitud`, `y`, `coord_y`, `lat_wgs84` | `lat`, `y`, `coord_y`, `dec_lat`, `wgs84_y` |
| **`profile_code`** | `perfil`, `id_perfil`, `codigo`, `sitio`, `calicata`, `sondeo` | `profile_id`, `pedon_id`, `site_id`, `plot_id`, `sample_id` |
| **`Horizon`** | `horizonte`, `hor`, `hz`, `capa`, `estrato` | `horizon`, `hz`, `layer`, `sublayer` |
| **`upper`** | `prof_sup`, `desde`, `limite_sup`, `prof_inicial`, `top_depth` | `upper`, `top`, `from`, `upper_depth`, `depth_top` |
| **`lower`** | `prof_inf`, `hasta`, `limite_inf`, `prof_final`, `bottom_depth`| `lower`, `bottom`, `to`, `lower_depth`, `depth_bottom` |
| **`SOC`** | `cos`, `cot`, `co`, `c_org`, `carbono_organico`, `carbono` | `soc`, `oc`, `c_org`, `org_c`, `organic_carbon` |
| **`OM`** | `om`, `mo`, `materia_organica`, `mat_org`, `som` | `om`, `organic_matter`, `som` |
| **`pH_H2O`** | `ph`, `ph_h2o`, `ph_agua`, `ph_suelo` | `ph`, `ph_water`, `ph_h2o` |
| **`Clay`** | `arcilla`, `arcillas`, `%arcilla` | `clay`, `clay_pct`, `clay_%` |
| **`Sand`** | `arena`, `arenas`, `%arena` | `sand`, `sand_pct`, `sand_%` |
| **`Silt`** | `limo`, `limos`, `%limo` | `silt`, `silt_pct`, `silt_%` |
| **`BD`** | `da`, `densidad_aparente`, `dens_apar` | `bd`, `bulk_density`, `dry_bulk_density` |
| **`CEC`** | `cic`, `cec`, `capacidad_intercambio_cationico` | `cec`, `ecec`, `cat_exch_cap` |

> **Organic Matter Note**: If the dataset contains Organic Matter (`MO`, `OM`) instead of SOC, calculate SOC using the standard Van Bemmelen conversion: $SOC = OM / 1.724$.

---

## 2. Incremental Procedure & Criteria Groups

### Criterion 1: Variable Identification & Confirmation (Step 1.1)
The AI generates a short, focused script `02_scripts/01_byod_audit.R` (< 60 lines) that:
1. Loads the dataset.
2. Identifies matching columns using the alias dictionary.
3. Subsets and keeps **ONLY** the relevant columns, discarding non-essential metadata.
4. Prints a clean, formatted table in the RStudio console comparing:
   `[Original Column Name] ---> [Standard Target Name]`.
5. Prompts the student:
   *"Por favor corre el script en RStudio y revisa la tabla en la consola. ¿Las columnas detectadas corresponden a lo que esperas? Confirma si es correcto o indica qué nombres corregir."*

**STOP AND WAIT**: The AI must NOT deliver the subsequent steps until the student confirms or corrects the mappings!

---

### Criterion 2: Spatial Validation & Geographic Plausibility (Step 1.2)
Once variables are confirmed by the student:
1. Validate coordinates: numeric check, remove NAs, bounds [-180, 180] and [-90, 90], swap detection.
2. Generate interactive `mapview` showing the spatial distribution of profiles.
3. Prompt the student to confirm whether the points fall within the country's borders or if any land in the ocean.

---

### Criterion 3: Depths, Pedological Sanity & Export (Step 1.3)
Once spatial validation is confirmed:
1. Validate depths (`upper >= 0`, `lower > upper`), detect overlapping layers.
2. Check physical ranges (pH 3–10.5, SOC 0–50%, texture sum ~ 100%).
3. Calculate missing Bulk Density (BD) via Saxton pedotransfer function if applicable.
4. Export clean dataset to `01_data/profiles/cleaned_profiles.csv`.
5. Produce bivariate sanity plot (`ggplot2` SOC vs BD).
