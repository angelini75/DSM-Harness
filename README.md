# DSM-Harness: Digital Soil Mapping & Soil Spectroscopy AI Training Harness

🌐 **Language / Idioma**: **[English]** | [Español](README.es.md)

> **AI-Orchestrated Training Harness for In-Person Digital Soil Mapping (DSM) & Soil Spectroscopy (DRS) Courses.**

This repository enables participants in in-person Digital Soil Mapping and Soil Spectroscopy training courses to generate reproducible, robust, and standardized R code using Artificial Intelligence, acting as **soil scientists and critical evaluators** without getting bogged down by manual programming syntax.

The workflow is modular and easily adaptable to courses of varying duration (3, 4, or 5 days), focusing on practical problem solving and pedological interpretation.

---

## 📖 How to Use This Repository (Step-by-Step Beginner's Guide)

If you are new to GitHub or terminal environments, follow these steps in order:

### Step 1: Download the Repository to Your Computer

Choose **Option A** if you do not have Git installed:

* **Option A (Direct ZIP Download - Recommended for beginners):**
  1. At the top of this GitHub page, click the green button labeled **`<> Code`**.
  2. In the dropdown menu, click **`Download ZIP`**.
  3. Once downloaded (`DSM-Harness-main.zip`), locate it in your *Downloads* folder, right-click it, and select **"Extract All..."** (or *Unzip*).
  4. Extract it to an easily accessible folder on your computer (for example, `C:\DSM-Harness` on Windows or in your `Documents` folder). **Make sure to open the extracted folder where the project files are visible.**

* **Option B (Clone with Git if Git is installed):**
  Open your terminal or command prompt and run:
  ```bash
  git clone https://github.com/angelini75/DSM-Harness.git
  cd DSM-Harness
  ```

---

### Step 2: Verify Your R & RStudio Environment

Before opening RStudio, run the automated verification script. It will detect your R and RStudio installations and automatically verify or install all required packages (`terra`, `sf`, `ranger`, `caret`, `Boruta`, `prospectr`, etc.).

* **On Windows:**
  1. Open the folder where you extracted the project.
  2. Right-click on an empty space inside the folder and select **"Open in Terminal"** or **"Open PowerShell window here"**.  
     *(Alternatively, press the Windows key, search for `PowerShell`, open it, and type `cd C:\Path\To\Your\DSM-Harness`)*.
  3. Type the following command and press Enter:
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\check_environment.ps1
     ```
  4. The script will test your environment and install any missing R packages into your personal user library.

* **On macOS or Linux:**
  1. Open the **Terminal** application.
  2. Navigate to your project directory (e.g. `cd ~/Documents/DSM-Harness`).
  3. Make the script executable and run it:
     ```bash
     chmod +x check_environment.sh
     ./check_environment.sh
     ```

---

### Step 3: Open the Project in RStudio

1. In your file explorer, navigate inside the project folder.
2. Find the file named **`DSM-Harness.Rproj`** and **double-click** it.
3. **RStudio** will launch.
4. **Why is this step essential?**  
   Opening `.Rproj` anchors RStudio's working directory (`getwd()`) directly to the project root. This guarantees that all relative paths (`01_data/`, `02_scripts/`, `03_outputs/`) resolve properly without ever needing manual path configuration.

---

### Step 4: Choose Your AI Interaction Mode

Choose **Mode B** if you are using free web chat accounts in your browser:

#### Mode A: Inside Your AI IDE (Antigravity, Cursor, or VS Code Copilot)
If you have an AI-assisted IDE environment:
- The agent will automatically read [`AGENTS.md`](AGENTS.md) and the specialized roles in `agents/`.
- Simply interact in your preferred language requesting workflow tasks (e.g. *"Act as dsm-panel and audit my dataset in 01_data/profiles/national_soils.csv"*).

#### Mode B: In Free Web Chats (ChatGPT, Gemini, or Claude)
If you are using the free web version of any AI in your browser:
1. Inside the project folder, open the **[`cards/en/`](cards/en/)** directory (or [`cards/es/`](cards/es/) for Spanish).
2. Open the prompt card corresponding to your current workshop stage (e.g. `01-byod-audit-card.md`).
3. Copy the text block inside the prompt.
4. Replace the bracketed placeholders (like `{{MY_FILENAME.csv}}` or `{{TARGET_PROPERTY}}`) with your real dataset names.
5. Paste it into your AI web chat.
6. The AI will output the exact R code ready to paste into RStudio, complete with diagnostic plots and guided pedological interpretation questions.

> 💡 **If a script produces an error in RStudio**: Never paste your entire 300-line script to the AI. Open **[`cards/en/00-error-rescue.md`](cards/en/00-error-rescue.md)**, copy the prompt, and paste only the error message and the 4 preceding lines. This saves token quotas and provides an instant fix.

---

## 🗺️ Modular Workflow (The 5 Stages)

The curriculum is structured into 5 sequential stages, independent of the total number of course days:

| Stage | Methodological Module | Task Card | Core Objective |
| :--- | :--- | :--- | :--- |
| **00** | Express Debugger | [`cards/en/00-error-rescue.md`](cards/en/00-error-rescue.md) | **Error Rescue**: 1-line diagnosis and minimal patch snippet (saves token quotas). |
| **01** | Data Audit | [`cards/en/01-byod-audit-card.md`](cards/en/01-byod-audit-card.md) | **BYOD Audit**: Coordinate checks in national bbox, ISO 28258 horizon validation, and pedological scatterplots. |
| **02** | SCORPAN Covariates | [`cards/en/02-covariates-card.md`](cards/en/02-covariates-card.md) | **Spatial Extraction**: Raster stack inspection, CRS reprojection, and point extraction (`dat_cov`). |
| **03** | Soil Spectroscopy | [`cards/en/03-spectra-card.md`](cards/en/03-spectra-card.md) | **Spectroscopy (DRS)**: Spectral preprocessing (`prospectr`: SNV, Savitzky-Golay), chemometrics calibration, and augmented dataset. |
| **04** | Predictive Modeling | [`cards/en/04-qrf-modeling-card.md`](cards/en/04-qrf-modeling-card.md) | **Quantile Regression Forest**: Boruta selection, QRF tuning with `ranger`/`caret`, metrics, and 1:1 plot. |
| **05** | Mapping & Delivery | [`cards/en/05-prediction-opennsis-card.md`](cards/en/05-prediction-opennsis-card.md) | **Spatial Prediction & OpenNSIS**: Tiled quantile interpolation (mean & uncertainty), COG export, and ISO 19139 metadata. |

---

## 🏛️ Disciplinary Roles

The harness separates concerns across 4 specialized professional roles that can be consulted individually or via the unified panel:

- 💻 **`r-engineer` ([R Specialist](agents/r-engineer.md))**: Generates robust, clean R code strictly adhering to the official reference script `02_scripts/reference_modelling_v2.R`.
- 🌍 **`geo-standards` ([Geospatial & OpenNSIS Architect](agents/geo-standards.md))**: Audits CRS projections, raster resolutions, Cloud-Optimized GeoTIFF compliance (`DEFLATE`, `predictor 2`, `nodata = -9999`), and OpenNSIS layer naming.
- 📊 **`geostat-modeler` ([Geostatistician & Pedometrician](agents/geostat-modeler.md))**: Oversees Boruta variable selection, repeated cross-validation, accuracy metrics ($R^2$, RMSE, CCC), and uncertainty intervals.
- 🔬 **`soil-scientist` ([Pedologist & Soil Interpreter](agents/soil-scientist.md))**: Evaluates pedological plausibility (carbon vs bulk density, pH vs cations, landscape features) and formulates guided reflection questions.
- 👥 **`dsm-panel` ([Unified Panel](agents/dsm-panel.md))**: Single-turn collaborative mode delivering [1] R Code, [2] Geospatial check, [3] Statistical checkpoints, and [4] Pedological questions in a single response.

---

## 🌐 OpenNSIS Integration (UN-FAO)

All continuous map products generated by the harness follow the **UN-FAO [OpenNSIS](https://github.com/un-fao/OpenNSIS) / GloSIS** spatial data infrastructure standards:
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
│   ├── reference_modelling_v2.R            # Official reference modeling script
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

## 🔗 Reference Repositories

- [OpenNSIS](https://github.com/un-fao/OpenNSIS) — Open National Soil Information System (FAO).
- [SoilFER-Training-Manual](https://github.com/SoilFER/SoilFER-Training-Manual) — Technical Manual for SoilFER Training.
- [SoilFER-Training-Resources](https://github.com/SoilFER/SoilFER-Training-Resources) — Code, scripts, and practice datasets for SoilFER Training.
