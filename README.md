# DSM-Harness: Digital Soil Mapping & Soil Spectroscopy AI Training Harness

🌐 **Language / Idioma**: **[English]** | [Español](README.es.md)

> **AI-Orchestrated Training Harness for In-Person Digital Soil Mapping (DSM) & Soil Spectroscopy (DRS) Courses.**

This repository enables participants in in-person Digital Soil Mapping and Soil Spectroscopy training courses to generate reproducible, robust, and standardized R code using Artificial Intelligence, acting as **soil scientists and critical evaluators** without getting bogged down by manual programming syntax.

The workflow is modular and easily adaptable to courses of varying duration (3, 4, or 5 days), focusing on practical problem solving and pedological interpretation.

---

> 💡 **Optimized for Participants Without Paid AI Subscriptions**  
> The entire harness, agent directives, and prompt cards have been **specifically engineered for users who DO NOT have paid AI accounts** (such as ChatGPT Plus, Claude Pro, or Gemini Advanced).  
> All prompts are atomic, direct, and consume minimal tokens. This guarantees that participants can complete the entire training workflow using the **free quotas and free tiers** of Gemini, ChatGPT, Claude, or Antigravity without hitting rate limits or exhausting daily usage quotas.

---

## 🎯 Data Scope: What variables does the harness need?

This harness is tailored **specifically for the Digital Soil Mapping (DSM) and Soil Spectroscopy (DRS) spatial modeling workflows**. **It is not intended to serve as an exhaustive database for all national soil survey attributes**.

National soil survey files frequently contain dozens of accessory survey columns (taxonomic classifications, survey dates, field morphology notes, land use, geology, drainage, etc.). **For the spatial predictive modeling in this training, those extraneous variables are not relevant and are filtered out** during data preparation.

The harness strictly targets the minimum core variables required for digital mapping:
1. **Profile Identifier** (`profile_code` / `id_perfil`).
2. *(Optional)* **Horizon / Layer Designation** (`Horizon` / `horizonte`).
3. **Depth Limits** (`upper` / top boundary, and `lower` / bottom boundary).
4. **Geographical Coordinates** in WGS84 (`longitude` and `latitude`).
5. **Key Analytical Soil Properties** to model (e.g., `SOC` / Soil Organic Carbon, `pH_H2O`, `Clay`, `Sand`, `Silt`, `BD` / Bulk Density, `CEC`).

---

## 🔄 Methodological Workflow: Incremental Validation by Criteria (Step-by-Step)

To prevent cognitive overload, unmanageable scripts, and token quota exhaustion, **the harness DOES NOT generate monolithic scripts that attempt to do everything at once**:

1. **The AI assumes that things can go wrong**: Column naming in national databases varies widely, often containing local abbreviations or distinct definitions.
2. **Interactive criteria-based cycle**:
   - **Step 1.1 (Variable Confirmation)**: The AI generates a very short, focused script whose sole purpose is to load the file, select relevant columns, print a clear comparison table in the RStudio console, and ask the student for confirmation.
   - **Awaiting Feedback**: The student runs this concise block in RStudio and replies in the chat: *"Yes, it's correct"* or *"No, column X is actually Y"*.
   - **Subsequent Criteria**: Only after variables are confirmed does the workflow proceed to spatial coordinate validation (Step 1.2), followed by depth and pedological consistency checks (Step 1.3).

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

## 🤖 How to Interact with Artificial Intelligence

Choose one of two interaction modes depending on your setup:

### Option A: How to Use this Repository with Google Antigravity (or AI IDEs)

If you are using **Google Antigravity** (or an editor with agent capabilities such as Cursor or VS Code with AI extensions):

1. **Open Workspace**: In Antigravity, go to `File -> Open Folder` and select the `DSM-Harness` project root.
2. **Automatic Indexing**: Antigravity automatically detects [`AGENTS.md`](AGENTS.md) as the project constitution, recognizing:
   - The 4 specialized roles in `agents/` (`r-engineer`, `geo-standards`, `geostat-modeler`, `soil-scientist`) and the unified `dsm-panel`.
   - Procedural skills under `skills/`.
   - The reference script at `02_scripts/reference_modelling_v2.R`.
3. **Prompting the Assistant**:
   Simply ask what you need in natural language (in English or Spanish). For example:
   - *"Act as dsm-panel and help me audit my soil profile data in 01_data/profiles/my_data.csv"*.
   - *"Act as r-engineer and generate the code to extract covariates to sample points"*.
   - *"Act as geostat-modeler and evaluate whether this 1:1 scatterplot indicates model overfitting"*.
   - *"Act as soil-scientist and tell me if this relationship between SOC and bulk density makes pedological sense"*.
4. **Structural Dataset Profiling, Tailored Script Generation, and Execution in RStudio**:
   - **No Guesswork Inspection**: When you point the assistant to your dataset (e.g., `01_data/profiles/Profiles_data.xlsx`), Antigravity executes a lightweight profiler (`02_scripts/inspect_dataset.py`) to read all Excel sheets, extract real column names, detect relational keys (e.g., `profile_id` linking sites and horizons), and examine sample values.
   - **Tailored Script Delivery**: Based on the discovered data structure, the AI writes a customized R script directly to `02_scripts/01_byod_audit.R` (including multi-sheet `left_join` if relational).
   - **Strict No-Heavy-Terminal-Processing Rule**: The AI only runs the quick structural metadata inspection; it never executes heavy data processing, spatial modeling, or plotting scripts on your terminal.
   - **Your Role as Soil Scientist**: Open the generated `.R` file in RStudio (which already has `DSM-Harness.Rproj` open), run it line by line, verify the mapping table in the console, and confirm or adjust in the chat before moving to subsequent criteria.

---

### Option B: How to Use this Repository with Free Online Web Chats (ChatGPT, Gemini, Claude)

If you do **not** have Antigravity or an AI IDE, you can use any free web chat in your browser (Google Gemini, ChatGPT, Claude, Copilot, or Perplexity) without paying for a subscription:

1. **Open Your Web Chat**: Open your browser and go to your preferred free AI chat (e.g. [Gemini](https://gemini.google.com), [ChatGPT](https://chat.openai.com), or [Claude](https://claude.ai)).
2. **Locate the Prompt Cards**: Inside the project directory, navigate to **[`cards/en/`](cards/en/)** (or [`cards/es/`](cards/es/) for Spanish).
3. **Select the Current Stage**: Open the task card matching your current activity (e.g. `01-byod-audit-card.md` for data audit, or `04-qrf-modeling-card.md` for modeling).
4. **Fill In Your Placeholders**:
   Copy the text block under `[PROMPT TO COPY AND PASTE]` and replace the bracketed placeholders with your actual dataset details:
   - `{{MY_FILENAME.csv}}` $\rightarrow$ filename in `01_data/profiles/`.
   - `{{TARGET_PROPERTY}}` $\rightarrow$ target variable (e.g. `SOC` or `pH`).
   - `{{COUNTRY_OR_ISO_CODE}}` $\rightarrow$ your country name or code.
5. **Paste into Web Chat**: Submit the prompt. The AI will respond with:
   - A clean R code block ready to run in RStudio.
   - A mandatory diagnostic plot (`mapview`, `ggplot2`, or Viridis).
   - 2 or 3 pedological reflection questions to help you interpret the visual result.
6. **Execute in RStudio**: Copy the generated code into your RStudio console or script file and run it.

> 🚨 **GOLDEN RULE FOR ERRORS (Free-Tier Token Conservation)**:  
> If an R script produces an error in your RStudio console, **NEVER paste your entire 200-line script into the web chat** (this quickly burns through your token limit).  
> Instead, open **[`cards/en/00-error-rescue.md`](cards/en/00-error-rescue.md)**, copy the template, and paste **only the red error message and the 4 lines of code preceding it**.  
> The AI is strictly instructed to give you a 1-line diagnosis and the minimal 2-5 line replacement snippet, resolving the error instantly while saving your quota.

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
