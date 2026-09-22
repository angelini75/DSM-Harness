# DSM-Harness: Digital Soil Mapping & Soil Spectroscopy AI Training Harness

🌐 **Language / Idioma**: **[English]** | [Español](README.es.md)

> **AI-Orchestrated Training Harness for Intensive Digital Soil Mapping & Soil Spectroscopy Workshops (FAO / SoilFER / SICA Countries).**

This repository enables participants in 3.5-day intensive workshops to generate reproducible, robust, and standardized R code using Artificial Intelligence, acting as **soil scientists and critical evaluators** without getting bogged down by manual programming syntax.

---

## 🚀 Quick Start in 3 Steps

### Step 1: Verify Local R & RStudio Environment
Open your terminal in the repository root directory and run the diagnostic script for your operating system:

- **On Windows (PowerShell):**
  ```powershell
  .\check_environment.ps1
  ```
- **On macOS or Linux (Terminal):**
  ```bash
  chmod +x check_environment.sh
  ./check_environment.sh
  ```
The script will check that R and RStudio are installed, and verify or install all required libraries (`terra`, `sf`, `ranger`, `caret`, `Boruta`, `prospectr`, `mapview`, `tidyverse`, `aqp`).

### Step 2: Open Project in RStudio
Double-click the **`DSM-Harness.Rproj`** file.  
This automatically sets the workspace root so that all relative paths (`01_data/`, `02_scripts/`, `03_outputs/`) resolve seamlessly without working directory errors.

### Step 3: Choose Your AI Assistance Mode

Choose one of two interaction modes depending on your setup:

#### Mode A: Inside Your AI IDE (Antigravity, Cursor, or VS Code Copilot)
If you use an AI-assisted IDE, the agent will automatically read [`AGENTS.md`](AGENTS.md) and the disciplinary roles in `agents/`. Simply ask for what you need in your language (e.g. *"Act as dsm-panel and audit my dataset in 01_data/profiles/my_country_soil.csv"*).

#### Mode B: In Free Web Chats (ChatGPT, Gemini, or Claude)
If you do not have an AI IDE or are using free web chat accounts:
1. Open the [`cards/en/`](cards/en/) folder (or [`cards/es/`](cards/es/) for Spanish).
2. Open the task card corresponding to your current workshop stage.
3. Copy the prompt block, fill in your placeholders (e.g. country code, property, or filename), and paste it into your web chat.
4. The AI will return the exact R script with diagnostic plots and guided pedological reflection questions.

---

## 🗺️ 3.5-Day Workshop Workflow (The 5 Stages)

| Stage | Agenda Session | Task Card | Core Objective |
| :--- | :--- | :--- | :--- |
| **00** | Any time | [`cards/en/00-error-rescue.md`](cards/en/00-error-rescue.md) | **Error Rescue**: 1-line diagnosis and minimal patch snippet (saves token quotas). |
| **01** | Day 1 PM / Day 2 AM | [`cards/en/01-byod-audit-card.md`](cards/en/01-byod-audit-card.md) | **BYOD Audit**: Coordinate check in country bbox, ISO 28258 horizon validation, and pedological scatterplots. |
| **02** | Day 2 PM | [`cards/en/02-covariates-card.md`](cards/en/02-covariates-card.md) | **Environmental Covariates**: SCORPAN raster stack inspection, CRS reprojection, and point extraction (`dat_cov`). |
| **03** | Day 3 AM | [`cards/en/03-spectra-card.md`](cards/en/03-spectra-card.md) | **Soil Spectroscopy (DRS)**: Spectral preprocessing (`prospectr`: SNV, Savitzky-Golay), calibration, and augmented dataset. |
| **04** | Day 3 PM | [`cards/en/04-qrf-modeling-card.md`](cards/en/04-qrf-modeling-card.md) | **QRF Modeling**: Boruta feature selection, Quantile Regression Forest (`ranger`/`caret`), metrics, and 1:1 plot. |
| **05** | Day 4 AM / PM | [`cards/en/05-prediction-opennsis-card.md`](cards/en/05-prediction-opennsis-card.md) | **Spatial Prediction & OpenNSIS**: Tiled quantile interpolation (mean & uncertainty), COG export, and ISO 19139 metadata. |

---

## 🏛️ Disciplinary Roles

The harness separates concerns across 4 specialized professional roles that can be consulted individually or via the unified panel:

- 💻 **`r-engineer` ([R Specialist](agents/r-engineer.md))**: Generates robust, clean R code strictly adhering to the official SoilFER reference script `02_scripts/reference_modelling_v2.R`.
- 🌍 **`geo-standards` ([Geospatial & OpenNSIS Architect](agents/geo-standards.md))**: Audits CRS projections, raster resolutions, Cloud-Optimized GeoTIFF compliance (`DEFLATE`, `predictor 2`, `nodata = -9999`), and OpenNSIS layer naming.
- 📊 **`geostat-modeler` ([Geostatistician & Pedometrician](agents/geostat-modeler.md))**: Oversees Boruta variable selection, repeated cross-validation, accuracy metrics ($R^2$, RMSE, CCC), and uncertainty intervals.
- 🔬 **`soil-scientist` ([Pedologist & Soil Interpreter](agents/soil-scientist.md))**: Evaluates pedological plausibility (carbon vs bulk density, pH vs cations, landscape features) and formulates guided reflection questions.
- 👥 **`dsm-panel` ([Unified Panel](agents/dsm-panel.md))**: Single-turn collaborative mode delivering [1] R Code, [2] Geospatial check, [3] Statistical checkpoints, and [4] Pedological questions in a single response.

---

## 🌐 OpenNSIS Integration (UN-FAO)

All continuous map products generated by the harness follow the **UN-FAO OpenNSIS / GloSIS** spatial data infrastructure standards:
- **Profile Data Model**: Conforms to ISO 28258 (see template in `01_data/templates/opennsis_profile_template.csv`).
- **Official Naming Convention**: `<COUNTRY_CODE>-<PROJECT>-<PROPERTY>-<DEPTH_UPPER>-<DEPTH_LOWER>-<STATISTIC>.tif`  
  *Examples:* `GTM-SOILFER-SOC-0-30-mean.tif` and `GTM-SOILFER-SOC-0-30-sd.tif`.
- **Raster Format**: Cloud-Optimized GeoTIFF (COG), `COMPRESS=DEFLATE`, `PREDICTOR=2`, 512px internal tiles, `nodata = -9999`.
- **Metadata**: Companion ISO 19139 XML metadata sidecars for registration in pyCSW catalogues.
- **Non-Blocking Rule**: Non-standard properties or naming conventions trigger educational advisories rather than halting execution.

---

## 📁 Repository Structure

```text
DSM-Harness/
├── .gitignore
├── DSM-Harness.Rproj                       # RStudio project file
├── README.md                               # English guide (this file)
├── README.es.md                            # Guía en Español
├── AGENTS.md                               # Master runtime index for AI agents
├── check_environment.ps1                   # Windows environment check (PowerShell)
├── check_environment.sh                    # macOS / Linux environment check (Bash)
│
├── 01_data/                                # Input datasets & templates
│   └── templates/                          # OpenNSIS ISO 28258 CSV template
│
├── 02_scripts/                             # Official R scripts
│   ├── 00_check_packages.R                 # Package checker & installer
│   ├── reference_modelling_v2.R            # Official SoilFER Module 3 reference script
│   └── eval.RData                          # Validation accuracy function
│
├── 03_outputs/                             # Output artifacts
│   ├── module3/models/                     # Trained models (.rds)
│   ├── module3/validation/                 # Accuracy tables (.csv)
│   ├── module3/tiles/                      # Intermediate tiles
│   ├── module3/maps/                       # Final continuous maps & XML metadata
│   └── module3/figures/                    # Diagnostic figures (Boruta, varImp, 1:1)
│
├── agents/                                 # 4 Disciplinary agent roles + unified panel
├── skills/                                 # Procedural DSM & spectroscopy contracts
├── cards/                                  # Web chat prompt cards
│   ├── es/                                 # Tarjetas de prompt en Español
│   └── en/                                 # Prompt cards in English
└── docs/                                   # Documentation (PRD, data contracts, OpenNSIS)
```

---

## 👥 Credits & References

- **FAO SoilFER (Soil Fertility and Mapping Project)**: Training manuals and official reference scripts (`SoilFER-Training-Manual`, `SoilFER-Training-Resources`).
- **Lead Instructors**: Marcos Angelini & Leonardo Ramirez-Lopez (FAO).
- **OpenNSIS Platform**: ISRIC World Soil Information & UN-FAO GloSIS Federation.
- **License**: MIT.
