---
name: spatial-prediction
description: Memory-safe tiled spatial prediction, quantile uncertainty interpolation, mosaicing, and Viridis cartography.
---

# Skill: Tiled Spatial Prediction & Uncertainty Mapping

This skill implements Session 2 of the official SoilFER reference script (`02_scripts/reference_modelling_v2.R`).

---

## 1. Procedure & Reference Implementation

### Step 1: Memory-Efficient Tiling Grid
```r
library(terra)

# Terra memory settings
terraOptions(progress = 1, memfrac = 0.6, tempdir = file.path(getwd(), "terra_tmp"))

# Define tile grid over covariate extent
r <- covs[[1]]
t <- rast(nrows = 5, ncols = 10, extent = ext(r), crs = crs(r))
tile <- makeTiles(r, t, overwrite = TRUE, filename = "03_outputs/module3/tiles/tiles.tif")
```

### Step 2: Prediction Function & Interpolation Loop
```r
ranger_model <- model$finalModel

# Prediction function for Quantile RF
pfun <- function(...) {
  predict(...)$predictions |> t()
}

gdal_opts <- c("COMPRESS=LZW")

# Loop through all tiles
for (j in seq_along(tile)) {
  message(paste("Processing tile", j, "of", length(tile)))
  
  t_j <- rast(tile[j])
  covs_tile <- crop(covs, t_j)
  
  # 1. Predict MEAN
  mean_file <- paste0("03_outputs/module3/tiles/", target, "_mean_", j, ".tif")
  terra::interpolate(
    covs_tile,
    model = ranger_model,
    fun = pfun,
    na.rm = TRUE,
    type = "quantiles",
    what = mean,
    filename = mean_file,
    overwrite = TRUE,
    wopt = list(datatype = "FLT4S", gdal = gdal_opts)
  )
  
  # 2. Predict STANDARD DEVIATION (Uncertainty)
  sd_file <- paste0("03_outputs/module3/tiles/", target, "_sd_", j, ".tif")
  terra::interpolate(
    covs_tile,
    model = ranger_model,
    fun = pfun,
    na.rm = TRUE,
    type = "quantiles",
    what = sd,
    filename = sd_file,
    overwrite = TRUE,
    wopt = list(datatype = "FLT4S", gdal = gdal_opts)
  )
}
```

### Step 3: Mosaic Tiles into Continuous Maps
```r
# Mosaic Mean
mean_tiles <- list.files("03_outputs/module3/tiles/",
                         pattern = paste0("^", target, "_mean_.*\\.tif$"),
                         full.names = TRUE)
mean_rasters <- lapply(mean_tiles, rast)
pred_mean <- mosaic(sprc(mean_rasters), fun = "first")
names(pred_mean) <- paste0(target, "_mean")

writeRaster(pred_mean, paste0("03_outputs/module3/maps/mean_", target, ".tif"),
            overwrite = TRUE, wopt = list(datatype = "FLT4S", gdal = gdal_opts))

# Mosaic Standard Deviation
sd_tiles <- list.files("03_outputs/module3/tiles/",
                       pattern = paste0("^", target, "_sd_.*\\.tif$"),
                       full.names = TRUE)
sd_rasters <- lapply(sd_tiles, rast)
pred_sd <- mosaic(sprc(sd_rasters), fun = "first")
names(pred_sd) <- paste0(target, "_sd")

writeRaster(pred_sd, paste0("03_outputs/module3/maps/sd_", target, ".tif"),
            overwrite = TRUE, wopt = list(datatype = "FLT4S", gdal = gdal_opts))

# Compute Coefficient of Variation (Relative Uncertainty)
pred_cv <- pred_sd / pred_mean
names(pred_cv) <- paste0(target, "_cv")
writeRaster(pred_cv, paste0("03_outputs/module3/maps/cv_", target, ".tif"),
            overwrite = TRUE, wopt = list(datatype = "FLT4S", gdal = gdal_opts))
```

### Step 4: Visual Inspection Plot
```r
par(mfrow = c(1, 2), mar = c(2, 2, 3, 4))
plot(pred_mean, main = paste("Predicted Mean", target), col = hcl.colors(100, "Viridis"))
plot(pred_sd, main = paste("Uncertainty (SD)", target), col = hcl.colors(100, "Inferno"))
par(mfrow = c(1, 1))
```
