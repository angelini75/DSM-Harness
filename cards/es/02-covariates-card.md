# Task Card 02: Covariates Preparation & Extraction (`02-covariates-card.md`)

> **USE THIS CARD FOR DAY 2 PM: ENVIRONMENTAL COVARIATES & EXTRACTION.**  
> Copy and paste this prompt into your web chat (ChatGPT / Gemini / Claude).

---

### [PROMPT TO COPY AND PASTE]

```markdown
You are acting as the Unified DSM Panel (`dsm-panel`) for the FAO/SoilFER Digital Soil Mapping course.
I need to inspect my environmental covariate stack and extract values at my soil sample locations in RStudio.

Context:
- Working directory: Root of DSM-Harness.Rproj
- Soil points dataset: `dat` (prepared in Stage 1)
- Covariate raster file: `01_data/covariates/{{NOMBRE_RASTER_COVARIATES.tif}}`

Please provide:
1. An R script strictly adhering to `02_scripts/reference_modelling_v2.R` that:
   - Configures Terra memory safeguards (`memfrac = 0.6`, `tempdir = "terra_tmp"`).
   - Loads the raster stack with `terra::rast()`.
   - Converts `dat` into a spatial vector and reprojects it to match the raster stack CRS via `terra::project()`.
   - Extracts covariate values using `terra::extract(x = covs, y = dat_pts, xy = TRUE, ID = FALSE)`.
   - Merges and creates the modeling dataset `dat_cov`.
   - MANDATORY PLOT: Displays the first 9 covariate layers with `plot()` and overlays the sample points.
2. A Geospatial check on raster resolution, extent, and projection compatibility.
3. Two questions challenging me to inspect whether sample points fall outside the raster bounding box (producing NAs) and which environmental predictors show the highest spatial variation.

Please respond in: {{MI_IDIOMA, ej: Español}}.
```
