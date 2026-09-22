# Task Card 01: BYOD Soil Data Audit & Diagnostic (`01-byod-audit-card.md`)

> **USE THIS CARD FOR DAY 1 PM / DAY 2 AM: DATA AUDIT & PREPARATION.**  
> Copy and paste this prompt into your web chat (ChatGPT / Gemini / Claude).

---

### [PROMPT TO COPY AND PASTE]

```markdown
You are acting as the Unified DSM Panel (`dsm-panel`) for the FAO/SoilFER Digital Soil Mapping course.
I need to audit and prepare my national soil profile dataset (BYOD) in RStudio.

Context:
- Working directory: Root of DSM-Harness.Rproj
- Country: {{PAIS_O_CODIGO_ISO, ej: Guatemala / GTM}}
- Target Property: {{PROPIEDAD_OBJETIVO, ej: SOC o pH}}
- My file is located at: `01_data/profiles/{{NOMBRE_DE_MI_ARCHIVO.csv}}`

Please provide:
1. An R script that:
   - Reads the CSV file using `readr::read_csv()`.
   - Checks coordinates (EPSG:4326), validates depths (`upper >= 0`, `lower > upper`).
   - Estimates Bulk Density via the Saxton pedotransfer function if missing.
   - MANDATORY PLOT 1: An interactive map of sample points using `mapview`.
   - MANDATORY PLOT 2: A scatterplot checking pedological bivariate coherence (e.g. SOC vs Bulk Density or pH vs Texture).
2. An OpenNSIS standards check (advising if column names match ISO 28258).
3. Two pedological questions challenging me to inspect the distribution of points and outlier values in the plots.

Please respond in: {{MI_IDIOMA, ej: Español}}.
```
