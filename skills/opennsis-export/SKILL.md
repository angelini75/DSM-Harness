---
name: opennsis-export
description: Exporting DSM rasters to Cloud-Optimized GeoTIFF (COG) and generating ISO 19139 metadata sidecars for OpenNSIS ingestion.
---

# Skill: OpenNSIS Ingestion Export & Metadata Generation

This skill formats final DSM prediction and uncertainty rasters for immediate publication into an **OpenNSIS / GloSIS** country node.

---

## 1. Procedure & Reference Implementation

### Step 1: Format as Cloud-Optimized GeoTIFF (COG)
```r
library(terra)

# Define country and project metadata
country_code <- "GTM"     # ISO 3166-1 alpha-3 (e.g. BLZ, CRI, DOM, SLV, GTM, HND, PAN)
project_id   <- "SOILFER" # Project name
prop_id      <- "SOC"     # Property code
d_upper      <- 0         # Upper depth (cm)
d_lower      <- 30        # Lower depth (cm)

# Enforce OpenNSIS COG options
gdal_cog_opts <- c(
  "COMPRESS=DEFLATE",
  "PREDICTOR=2",
  "TILED=YES",
  "BLOCKXSIZE=512",
  "BLOCKYSIZE=512"
)

# Set NoData value explicitly to -9999
NAflag(pred_mean) <- -9999
NAflag(pred_sd)   <- -9999

# Build standard OpenNSIS filenames
mean_cog_name <- sprintf("%s-%s-%s-%d-%d-mean.tif", country_code, project_id, prop_id, d_upper, d_lower)
sd_cog_name   <- sprintf("%s-%s-%s-%d-%d-sd.tif", country_code, project_id, prop_id, d_upper, d_lower)

mean_cog_path <- file.path("03_outputs/module3/maps", mean_cog_name)
sd_cog_path   <- file.path("03_outputs/module3/maps", sd_cog_name)

# Write Cloud-Optimized GeoTIFFs
writeRaster(pred_mean, mean_cog_path, overwrite = TRUE, datatype = "FLT4S", gdal = gdal_cog_opts)
writeRaster(pred_sd, sd_cog_path, overwrite = TRUE, datatype = "FLT4S", gdal = gdal_cog_opts)

message("Saved OpenNSIS compliant COG: ", mean_cog_path)
message("Saved OpenNSIS compliant COG: ", sd_cog_path)
```

### Step 2: Generate Companion ISO 19139 Metadata Sidecar
```r
# Extract bounding box in WGS 84
bbox_wgs84 <- ext(project(pred_mean, "epsg:4326"))

metadata_xml <- sprintf('<?xml version="1.0" encoding="UTF-8"?>
<gmd:MD_Metadata xmlns:gmd="http://www.isotc211.org/2005/gmd" xmlns:gco="http://www.isotc211.org/2005/gco">
  <gmd:fileIdentifier><gco:CharacterString>%s</gco:CharacterString></gmd:fileIdentifier>
  <gmd:identificationInfo>
    <gmd:MD_DataIdentification>
      <gmd:citation>
        <gmd:CI_Citation>
          <gmd:title><gco:CharacterString>%s %s %d-%d cm (%s)</gco:CharacterString></gmd:title>
          <gmd:date><gmd:CI_Date><gmd:date><gco:Date>%s</gco:Date></gmd:date></gmd:CI_Date></gmd:date>
        </gmd:CI_Citation>
      </gmd:citation>
      <gmd:abstract><gco:CharacterString>Digital Soil Map generated using Quantile Regression Forest (SoilFER methodology) for %s.</gco:CharacterString></gmd:abstract>
      <gmd:extent>
        <gmd:EX_Extent>
          <gmd:geographicElement>
            <gmd:EX_GeographicBoundingBox>
              <gmd:westBoundLongitude><gco:Decimal>%.4f</gmd:Decimal></gmd:westBoundLongitude>
              <gmd:eastBoundLongitude><gco:Decimal>%.4f</gmd:Decimal></gmd:eastBoundLongitude>
              <gmd:southBoundLatitude><gco:Decimal>%.4f</gmd:Decimal></gmd:southBoundLatitude>
              <gmd:northBoundLatitude><gco:Decimal>%.4f</gmd:Decimal></gmd:northBoundLatitude>
            </gmd:EX_GeographicBoundingBox>
          </gmd:geographicElement>
        </gmd:EX_Extent>
      </gmd:extent>
    </gmd:MD_DataIdentification>
  </gmd:identificationInfo>
</gmd:MD_Metadata>',
  mean_cog_name, country_code, prop_id, d_upper, d_lower, project_id,
  Sys.Date(), country_code,
  bbox_wgs84$xmin, bbox_wgs84$xmax, bbox_wgs84$ymin, bbox_wgs84$ymax
)

writeLines(metadata_xml, file.path("03_outputs/module3/maps", paste0(mean_cog_name, ".xml")))
message("Generated ISO 19139 metadata sidecar.")
```
