# OpenNSIS Standards & FAO GloSIS Compliance (`OPENNSIS_STANDARDS.md`)

This guide details how **DSM-Harness** connects Digital Soil Mapping in R to the **UN-FAO Open National Soil Information System (OpenNSIS)**, ensuring that all student deliverables are immediately ready for ingestion into a national soil data node.

---

## 1. Overview of OpenNSIS

OpenNSIS is an open-source Spatial Data Infrastructure (SDI) designed by the FAO for the **GloSIS Federation** (Global Soil Information System). Each country node provides:
- A public **Web Mapping** interface (OpenLayers).
- An **Admin Panel** for soil-profile ETL and raster ingestion.
- An **OGC API Records / CSW** metadata catalogue (pyCSW).
- **WMS / WCS** services (MapServer).
- A **Federation API** (`sis-api-glosis`) connecting national data to the global GloSIS Discovery Hub.

---

## 2. Raster Product Standards (GeoTIFF / COG)

When producing final continuous maps of soil properties or uncertainty, OpenNSIS enforces strict GDAL specifications.

### Technical Profile
- **Format**: Cloud-Optimized GeoTIFF (COG).
- **Compression**: `DEFLATE`.
- **Predictor**: `2` (horizontal differencing for floating-point continuous data).
- **Tiling**: Internal tiles of `512x512` pixels.
- **Overviews**: Built internally with `nearest` or `average` resampling.
- **NoData Value**: Declared in band header as `-9999` (or `-3.4e38` for extreme float ranges).

### In R (`terra`):
To produce a compliant COG directly from R:
```r
gdal_cog_opts <- c(
  "COMPRESS=DEFLATE",
  "PREDICTOR=2",
  "TILED=YES",
  "BLOCKXSIZE=512",
  "BLOCKYSIZE=512"
)

writeRaster(
  rast_object,
  filename = output_path,
  overwrite = TRUE,
  datatype = "FLT4S",
  gdal = gdal_cog_opts
)
```

---

## 3. Standard File Naming Convention

OpenNSIS extracts layer metadata directly from filenames via pattern matching:
```text
<COUNTRY_CODE>-<PROJECT>-<PROPERTY>-<DEPTH_UPPER>-<DEPTH_LOWER>-<STATISTIC>.tif
```

### Components
1. `COUNTRY_CODE`: ISO 3166-1 alpha-3 code (e.g., `BLZ`, `CRI`, `DOM`, `SLV`, `GTM`, `HND`, `PAN`).
2. `PROJECT`: Project acronym (e.g., `SOILFER`, `AFACI`, `NSIS`).
3. `PROPERTY`: Standardized soil property code (`SOC`, `PH`, `CLAY`, `SAND`, `SILT`, `BD`, `CEC`).
4. `DEPTH_UPPER`: Top depth in centimeters (e.g., `0`).
5. `DEPTH_LOWER`: Bottom depth in centimeters (e.g., `30`).
6. `STATISTIC`: Statistical parameter represented by the layer:
   - `mean`: Conditional mean prediction.
   - `sd`: Conditional standard deviation (uncertainty).
   - `q05`: 5th percentile prediction.
   - `q50`: Median prediction.
   - `q95`: 95th percentile prediction.
   - `ci90`: 90% confidence interval width ($q_{0.95} - q_{0.05}$).

*Valid Examples:*
- `GTM-SOILFER-SOC-0-30-mean.tif`
- `GTM-SOILFER-SOC-0-30-sd.tif`
- `HND-SOILFER-PH-0-20-mean.tif`

---

## 4. Metadata Standard (ISO 19115 / 19139)

OpenNSIS uses pyCSW to publish metadata records. Each raster map product can be paired with an XML metadata sidecar (`<layer_name>.xml`) including:
- Bounding box coordinates (west, east, south, north in EPSG:4326).
- Pedological property description and analytical method.
- Statistical algorithm (e.g. *Quantile Regression Forest via ranger/caret*).
- Responsible party and institution.

---

## 5. Non-Blocking Warning Doctrine ("Soft Enforcement")

During the training course, adherence to OpenNSIS standards is **strongly recommended** but **never blocking**:
- If a participant’s national dataset contains non-standard column names or a property outside GloSIS codelists (e.g., available potassium via modified Olsen), the system issues a clear advisory:
  > `[OpenNSIS Advisory] Note: Property 'K_olsen' is not in standard GloSIS core codelists. Proceeding with DSM modeling under local code 'K_olsen'.`
- If an output raster is saved with LZW instead of DEFLATE or without full COG tiles, an advisory is printed with instructions on how to convert it via GDAL or R prior to server upload.
