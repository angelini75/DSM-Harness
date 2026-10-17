# Data Contract and Workspace Specifications (`DATA_CONTRACT.md`)

This document defines the strict data schemas, folder hierarchies, and naming standards enforced across the **DSM-Harness** repository. Every agent, script, and prompt card must adhere to these contracts to prevent runtime file path failures and column mismatch bugs.

---

## 1. Directory Structure Contract

The root of the workspace is anchored by `DSM-Harness.Rproj`. In RStudio, relative paths always evaluate from this root directory.

```text
DSM-Harness/
├── 01_data/                                # Raw inputs and external rasters
│   ├── templates/                          # Reference CSV schemas (OpenNSIS)
│   ├── covariates/                         # Environmental raster stacks (DEM, climate, RS)
│   └── profiles/                           # Point soil profile data (CSV)
│
├── 02_scripts/                             # R scripts
│   ├── 00_check_packages.R                 # Environment installer/verifier
│   ├── reference_modelling_v2.R            # SoilFER official Module 3 reference script
│   └── eval.RData                          # SoilFER model accuracy evaluation function
│
└── 03_outputs/                             # Standardized outputs
    ├── module3/
    │   ├── figures/                        # Boruta, varImp, scatterplot PNGs
    │   ├── maps/                           # Final mean & uncertainty rasters
    │   ├── maps/aoa/                       # Area of Applicability outputs
    │   ├── models/                         # Trained ranger .rds models
    │   ├── tiles/                          # Intermediate chunked GeoTIFFs
    │   └── validation/                     # Cross-validation accuracy tables (CSV)
    └── terra_tmp/                          # High-performance local scratch directory
```

---

## 2. Soil Profile Input Contract (OpenNSIS / ISO 28258)

Point soil observations should follow the **ISO 28258** relational structure used by the **UN-FAO OpenNSIS** platform (reference: `01_data/templates/opennsis_profile_template.csv`).

### Mandatory Spatial & Horizon Columns
| Column Name | Type | Unit / Format | Description |
| :--- | :--- | :--- | :--- |
| `project` | Character | String | Name of national or regional project |
| `profile_code` | Character | String | Unique profile / pedon identifier |
| `longitude` | Numeric | Decimal degrees (WGS 84, EPSG:4326) | X coordinate |
| `latitude` | Numeric | Decimal degrees (WGS 84, EPSG:4326) | Y coordinate |
| `Horizon` | Character | String (e.g. `A`, `Bw`, `Bt`, `C`) | Genetic or operational horizon label |
| `upper` | Numeric | Centimeters (cm) | Top boundary of horizon from soil surface (0) |
| `lower` | Numeric | Centimeters (cm) | Bottom boundary of horizon |

### Standard Target Property Codes
When harmonizing analytical properties, the following standard column codes are expected:
- `SOC`: Soil Organic Carbon ($\%$) or $g/kg$
- `pH_H2O` or `pH-H2O`: Soil pH in water (1:1 or 1:2.5)
- `Clay`: Clay content ($\%$, $< 0.002\,mm$)
- `Sand`: Sand content ($\%$, $0.05 - 2.0\,mm$)
- `Silt`: Silt content ($\%$, $0.002 - 0.05\,mm$)
- `BD`: Bulk Density ($g/cm^3$ or $kg/dm^3$) — can be estimated via Saxton PTF
- `CEC`: Cation Exchange Capacity ($cmol(+)/kg$ or $meq/100g$)

> **Non-blocking Rule**: If a country brings a dataset with custom column names (e.g., `carbono_organico`, `prof_sup`, `prof_inf`), the `byod-audit` skill maps them dynamically via a lookup vector rather than stopping execution.

---

## 3. Covariate Raster Contract (SCORPAN Stack)

Environmental predictor layers (relief derivatives, climate, satellite indices) must satisfy:
1. **Format**: GeoTIFF (`.tif`), preferably Cloud-Optimized GeoTIFF (COG).
2. **Alignment**: All rasters in a multi-covariate analysis must share identical extent, pixel resolution, and CRS (or be stacked into a single multi-band raster).
3. **NoData Value**: Must declare a formal NoData value (standardized to `-9999` in OpenNSIS).
4. **Memory Optimization**: Use `terraOptions(progress = 1, memfrac = 0.6, tempdir = "terra_tmp")` to prevent memory overflows.

---

## 4. Output Product Contract (OpenNSIS Compliance)

Every continuous soil map product generated for delivery must follow OpenNSIS publication standards:
- **Raster Type**: Cloud-Optimized GeoTIFF (COG).
- **Compression**: `COMPRESS=DEFLATE`, `PREDICTOR=2`, `TILED=YES`, `BLOCKXSIZE=512`, `BLOCKYSIZE=512`.
- **Naming Pattern**:
  `<COUNTRY_CODE>-<PROJECT>-<PROPERTY>-<DEPTH_UPPER>-<DEPTH_LOWER>-<STATISTIC>.tif`
  *Examples:*
  - `CRI-SOILFER-SOC-0-30-mean.tif` (Mean predicted SOC for Costa Rica 0-30 cm)
  - `CRI-SOILFER-SOC-0-30-sd.tif` (Standard deviation / uncertainty map)
- **Sidecar Metadata**: Companion ISO 19139 XML metadata file generated for pyCSW catalogue registration.
