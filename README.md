# DSM-Harness v2: Digital Soil Mapping AI Training Harness

> **AI-Orchestrated Training Harness for Digital Soil Mapping (DSM) Courses (FAO / SoilFER / OpenNSIS).**

DSM-Harness guides soil scientists and participants through reproducible, standardized Digital Soil Mapping workflows using Artificial Intelligence. Participants evaluate pedological plausibility, spatial distributions, and statistical quality while the harness handles execution and data contracts.

---

## 🎯 Architecture & Core Principles

1. **Clean Step Contracts**: Each step reads fixed input files and writes fixed output files. Nothing is passed through shared R global session memory.
2. **Project Isolation**: Every dataset lives in its own project folder under `projects/<name>/` with its own data, reports, and configuration.
3. **Agent-Managed Config**: The AI agent writes and maintains `config.json` based on step reports and user dialogue. Users confirm decisions in chat without editing JSON.
4. **Multilingual Interaction**: Console messages and diagnostic reports are fully internationalized via keyed catalogues (`02_scripts/i18n/` supporting English and Spanish).
5. **No Machine Learning for Bulk Density**: Compares measured samples against published Pedotransfer Functions (PTF catalogue) and fits local parametric curves when sample count is sufficient ($\ge 30$). Imputation occurs strictly in a separate column and only when explicitly confirmed.

---

## 📋 Pipeline Steps (Milestone M1)

| Step | Function Call | Reads | Writes | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **0 Inspect** | `run_step("0", project = "<name>")` | Raw dataset file | `reports/00_inspection.txt` | Exhaustive profiling of sheets, column types, % missing, and data ranges |
| **1.1 Map** | `run_step("1.1", project = "<name>")` | Raw data + `config.json` | `data/01_mapped.csv`<br>`reports/11_mapping.txt` | Variable selection, relational sheet join, duplicate key resolution |
| **1.2 Spatial** | `run_step("1.2", project = "<name>")` | `data/01_mapped.csv` | `data/02_spatial.csv`<br>`reports/12_spatial.txt` | Coordinate range audit, projected vs geographic diagnosis, reprojection to EPSG:4326 |
| **1.3 Pedological** | `run_step("1.3", project = "<name>")` | `data/02_spatial.csv` | `data/03_clean.csv`<br>`reports/13_pedological.txt` | Horizon depth validity, PTF bulk density contrast, optional local calibration |

---

## 📁 Project Directory Structure

```text
projects/<name>/
├── config.json          # Project configuration (roles, categories, CRS, etc.)
├── decisions_log.csv    # Automatically logged audit decisions
├── data/
│   ├── raw_dataset.*    # User's input file (CSV or multi-sheet Excel)
│   ├── 01_mapped.csv    # Output of Step 1.1
│   ├── 02_spatial.csv   # Output of Step 1.2
│   └── 03_clean.csv     # Output of Step 1.3
├── reports/
│   ├── 00_inspection.txt
│   ├── 11_mapping.txt
│   ├── 12_spatial.txt
│   └── 13_pedological.txt
├── covariates/          # Environmental covariates (Rasters/COGs)
├── outputs/             # Models and predicted GeoTIFF maps
└── custom/              # Optional local step override scripts (<step>.R)
```

---

## 🚀 Getting Started in RStudio

1. Open `DSM-Harness.Rproj` in RStudio.
2. Initialize a new project and load the runner:
   ```r
   source("run_step.R")
   new_project("MyProject")
   ```
3. Place your raw dataset inside `projects/MyProject/data/`.
4. Run Step 0 to profile your data:
   ```r
   run_step("0", project = "MyProject")
   ```
5. Review `projects/MyProject/reports/00_inspection.txt` with the AI assistant in the chat to establish column roles, categories, and target CRS in `config.json`.
6. Run subsequent steps sequentially:
   ```r
   run_step("1.1", project = "MyProject")
   run_step("1.2", project = "MyProject")
   run_step("1.3", project = "MyProject")
   ```

---

## 🧪 Testing

The test suite runs against synthetic test datasets under `tests/testthat/`:

```r
source("tests/testthat.R")
```

Or from the command line:
```bash
Rscript tests/testthat.R
```
