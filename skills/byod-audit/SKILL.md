---
name: byod-audit
description: Rapid diagnostic audit and cleaning procedure for national soil profile datasets (BYOD).
---

# Skill: BYOD National Soil Data Audit & Harmonization

This skill guides the participant through the exploratory data analysis, spatial validation, depth interval verification, and pedological sanity checks of their country dataset.

---

## 1. Procedure & Checklist

### Step 1: Spatial & Coordinate Audit
1. Load point data via `readr::read_csv()` or `readxl::read_excel()`.
2. Verify coordinate columns: identify `longitude` and `latitude`.
3. Check for obvious errors:
   - Inverted coordinates ($lat > 90$ or $lon > 180$).
   - Coordinates outside the national bounding box for the country (e.g. points falling into the ocean or neighboring countries).
4. Render interactive spatial map:
   ```r
   library(sf)
   library(mapview)
   pts <- st_as_sf(dat, coords = c("longitude", "latitude"), crs = 4326)
   mapview(pts, zcol = "project", cex = 3)
   ```

### Step 2: Soil Depth & Horizon Validation (ISO 28258)
1. Verify depth columns: `upper` and `lower` in centimeters.
2. Check consistency rules:
   - Rule 1: `upper >= 0` and `lower > upper`.
   - Rule 2: No negative depth values.
   - Rule 3: Detect overlapping horizon intervals within the same `profile_code`.
3. If slicing or standard depth intervals are required (e.g. 0-30 cm standard FAO/SoilFER depth), compute depth-weighted averages or filter to topsoil.

### Step 3: Pedological Plausibility & Bivariate Matrix
1. Generate statistical summary: `summary(dat[c("SOC", "pH_H2O", "Clay", "Sand", "Silt")])`.
2. Check physical limits:
   - $pH \in [3.0, 11.0]$
   - $Clay + Sand + Silt \approx 100\%$ (within $\pm 5\%$ tolerance).
   - $SOC \in [0.0, 60.0\%]$ (flag values $> 20\%$ as potential organic/peat soils or units mismatch).
3. Compute bulk density via Saxton PTF if missing:
   ```r
   dat <- dat %>%
     mutate(BD = 1.35 + 0.0045 * Sand + 0.0035 * Clay - 0.06 * 1.72 * SOC)
   ```
4. Plot bivariate relationship:
   ```r
   ggplot(dat, aes(x = SOC, y = BD)) +
     geom_point(alpha = 0.5, color = "darkgreen") +
     geom_smooth(method = "lm", se = FALSE, color = "black") +
     labs(title = "Pedological Check: SOC vs Bulk Density") +
     theme_minimal()
   ```

---

## 2. OpenNSIS Alignment Advisory
- If column names do not match the OpenNSIS template (`01_data/templates/opennsis_profile_template.csv`), generate an automated rename snippet:
  ```r
  # Standardize to OpenNSIS ISO 28258
  dat_clean <- dat %>%
    rename(
      profile_code = local_id_col,
      longitude = x_coord,
      latitude = y_coord,
      upper = depth_top,
      lower = depth_bottom,
      SOC = carbon_col
    )
  ```
- Issue an informative non-blocking advisory if non-standard properties are present.
