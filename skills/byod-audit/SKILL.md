---
name: byod-audit
description: Rapid diagnostic audit and cleaning procedure for national soil profile datasets (BYOD) in Excel or CSV.
---

# Skill: BYOD National Soil Data Audit & Harmonization

This skill guides the participant through the exploratory data analysis, spatial validation, depth interval verification, and pedological sanity checks of their country dataset (in `.xlsx` or `.csv`).

---

## 0. Fundamental Directives: File Generation, No Terminal Execution & Anti-Overfitting

> **CRITICAL DIRECTIVES**: 
> 1. **No Terminal Execution**: The AI assistant MUST NEVER execute R scripts, run `Rscript`, or attempt to process the student's data via background terminal commands.  
> 2. **File Generation in IDE Mode (Antigravity)**: Instead of pasting massive scripts into the chat, create or update the R script directly at `02_scripts/01_byod_audit.R`. The student will open and run it inside their own RStudio session. In Web Chat mode, provide the code block in the chat.
> 3. **Anti-Overfitting & Generalization**: Do NOT inspect, read, or overfit to the user's private test files. Formulate general, robust R scripts that incorporate dynamic column alias detection and standard pedological validation rules applicable to any national dataset.

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
| **`pH_H2O`** | `ph`, `ph_h2o`, `ph_agua`, `ph_suelo` | `ph`, `ph_water`, `ph_h2o` |
| **`Clay`** | `arcilla`, `arcillas`, `%arcilla` | `clay`, `clay_pct`, `clay_%` |
| **`Sand`** | `arena`, `arenas`, `%arena` | `sand`, `sand_pct`, `sand_%` |
| **`Silt`** | `limo`, `limos`, `%limo` | `silt`, `silt_pct`, `silt_%` |
| **`BD`** | `da`, `densidad_aparente`, `dens_apar` | `bd`, `bulk_density`, `dry_bulk_density` |
| **`CEC`** | `cic`, `cec`, `capacidad_intercambio_cationico` | `cec`, `ecec`, `cat_exch_cap` |

> **Organic Matter Note**: If the dataset contains Organic Matter (`MO`, `OM`, `materia_organica`) instead of SOC, calculate SOC using the standard Van Bemmelen conversion: $SOC = OM / 1.724$.

---

## 2. Procedure & Script Delivery

When the student provides a file (e.g. `01_data/profiles/my_data.xlsx`), deliver an R script structured as follows:

```r
# ==============================================================================
# Step 1: BYOD Soil Profile Audit & Cleaning
# Run this script in RStudio
# ==============================================================================

library(tidyverse)
library(readxl)  # or library(readr) for CSV
library(sf)
library(mapview)

# 1. Load the dataset
# Adjust sheet or file path if necessary
dat_raw <- read_excel("01_data/profiles/my_data.xlsx")

# 2. Harmonize column names to OpenNSIS / ISO 28258
dat <- dat_raw %>%
  rename(
    profile_code = {{INFERRED_ID_COL}},
    longitude    = {{INFERRED_LON_COL}},
    latitude     = {{INFERRED_LAT_COL}},
    upper        = {{INFERRED_UPPER_COL}},
    lower        = {{INFERRED_LOWER_COL}},
    SOC          = {{INFERRED_SOC_COL}}
  )

# 3. Spatial & Depth Quality Checks
# - Filter invalid coordinates
dat_clean <- dat %>%
  filter(!is.na(longitude) & !is.na(latitude)) %>%
  filter(latitude >= -90 & latitude <= 90 & longitude >= -180 & longitude <= 180) %>%
  # - Check depth validity
  filter(upper >= 0 & lower > upper)

# 4. Saxton PTF for Bulk Density (if BD is missing)
if (!"BD" %in% names(dat_clean) && all(c("Sand", "Clay", "SOC") %in% names(dat_clean))) {
  dat_clean <- dat_clean %>%
    mutate(BD = 1.35 + 0.0045 * Sand + 0.0035 * Clay - 0.06 * 1.72 * SOC)
}

# 5. DIAGNOSTIC PLOT 1: Interactive point distribution map
dat_sf <- st_as_sf(dat_clean, coords = c("longitude", "latitude"), crs = 4326)
mapview(dat_sf, zcol = "SOC", cex = 3)

# 6. DIAGNOSTIC PLOT 2: Pedological bivariate check
if ("BD" %in% names(dat_clean)) {
  ggplot(dat_clean, aes(x = SOC, y = BD)) +
    geom_point(alpha = 0.5, color = "forestgreen") +
    geom_smooth(method = "lm", se = FALSE, color = "black") +
    labs(title = "Pedological Check: SOC vs Bulk Density",
         x = "Soil Organic Carbon (%)", y = "Bulk Density (g/cm³)") +
    theme_minimal()
}
```

---

## 3. Post-Delivery Guidance

After providing the code, present:
1. **Mapping summary**: A clear list showing how each national column was mapped to the OpenNSIS standard.
2. **Ambiguity check**: If 1 or 2 columns could not be identified with certainty, ask the student what they represent.
3. **Pedological questions**: 2 sharp questions asking the student to examine point clusters (e.g. points falling into the ocean) and unexpected negative or extreme values in the scatterplot.
