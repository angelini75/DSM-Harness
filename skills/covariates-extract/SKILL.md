---
name: covariates-extract
description: Environmental covariates inspection, CRS harmonization, and point extraction for DSM.
---

# Skill: Covariate Preparation & Point Extraction

This skill standardizes the ingestion of environmental predictor rasters (DEM derivatives, satellite imagery, climate) and the extraction of values at soil observation locations.

---

## 1. Procedure & Checklist

### Step 1: Covariate Stack Inspection
1. Load raster stack using `terra::rast()`:
   ```r
   covs <- rast("01_data/covariates/Environmental_Covariates.tif")
   ```
2. Verify properties:
   - `crs(covs)` — Check projection.
   - `res(covs)` — Confirm pixel resolution.
   - `nlyr(covs)` — Count number of predictor layers.
   - `names(covs)` — Confirm descriptive layer names without spaces or invalid symbols.
3. Diagnostic multi-layer plot:
   ```r
   plot(covs[[1:min(9, nlyr(covs))]])
   ```

### Step 2: Harmonize CRS & Spatial Overlay
1. Convert tabular soil points into a `terra::SpatVector`:
   ```r
   dat_pts <- vect(dat, geom = c("longitude", "latitude"), crs = "epsg:4326")
   ```
2. Reproject points into the exact CRS of the raster stack:
   ```r
   dat_pts <- terra::project(dat_pts, covs)
   ```
3. Visual overlay check:
   ```r
   mapview(dat_pts, cex = 2) + mapview(covs[[1]])
   ```

### Step 3: Extract Covariates to Points
1. Extract values:
   ```r
   extracted_covs <- terra::extract(x = covs, y = dat_pts, xy = TRUE, ID = FALSE)
   ```
2. Inspect for missing data (`NA` count in extracted columns). Points falling outside raster extent will have all NAs.
3. Assemble modeling dataset (`dat_cov`):
   ```r
   dat <- as.data.frame(dat_pts)
   dat_cov <- bind_cols(dat, extracted_covs)
   ```

### Step 4: Diagnostic Inspection
1. Display summary of extracted predictors: `summary(extracted_covs)`.
2. Generate correlation plot among numerical covariates to detect severe multicollinearity.
