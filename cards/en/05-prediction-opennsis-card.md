# Task Card 05: Spatial Prediction & OpenNSIS Delivery (`05-prediction-opennsis-card.md`)

> **USE THIS CARD FOR DAY 4 AM/PM: SPATIAL PREDICTION, UNCERTAINTY & OPENNSIS EXPORT.**  
> Copy and paste this prompt into your web chat (ChatGPT / Gemini / Claude).

---

### [PROMPT TO COPY AND PASTE]

```markdown
You are acting as the Unified DSM Panel (`dsm-panel`) for the FAO/SoilFER Digital Soil Mapping course.
I need to generate continuous spatial prediction maps, uncertainty rasters, and export them conforming to OpenNSIS standards in RStudio.

Context:
- Working directory: Root of DSM-Harness.Rproj
- Trained model: `03_outputs/module3/models/ranger_model_{{TARGET_PROPERTY}}.rds`
- Covariate raster stack: `covs`
- Target property: `{{TARGET_PROPERTY, e.g. SOC}}`
- Country ISO code: `{{COUNTRY_ISO_CODE, e.g. BLZ, CRI, DOM, GTM, HND, PAN, SLV}}`
- Depth interval: `{{DEPTH_UPPER, e.g. 0}}` to `{{DEPTH_LOWER, e.g. 30}}` cm
- Reference script: Strictly follow Session 2 of `02_scripts/reference_modelling_v2.R`

Please provide:
1. An R script strictly adhering to `02_scripts/reference_modelling_v2.R` that:
   - Configures memory safeguards (`memfrac = 0.6`, `tempdir = "terra_tmp"`).
   - Generates a memory-safe tiling grid with `terra::makeTiles()`.
   - Loops through tiles predicting conditional MEAN and conditional STANDARD DEVIATION with `terra::interpolate(type = "quantiles")`.
   - Mosaics tiles into full continuous rasters (`pred_mean`, `pred_sd`).
   - Calculates the relative uncertainty (Coefficient of Variation: $CV = SD / Mean$).
   - MANDATORY PLOT: Displays side-by-side maps of Mean and Uncertainty using Viridis and Inferno color palettes.
   - Formats and exports both rasters as Cloud-Optimized GeoTIFFs (COG) with `COMPRESS=DEFLATE`, `PREDICTOR=2`, and `nodata = -9999`.
   - Saves files following OpenNSIS naming: `<CC>-SOILFER-<PROP>-<dim1>-<dim2>-mean.tif` and `<CC>-SOILFER-<PROP>-<dim1>-<dim2>-sd.tif`.
   - Generates a companion ISO 19139 metadata XML sidecar file for pyCSW catalogue registration.
2. Two questions challenging me to interpret the spatial distribution of soil properties across major landforms and explain the spatial clusters of high prediction uncertainty in my country.

Please respond in: English.
```
