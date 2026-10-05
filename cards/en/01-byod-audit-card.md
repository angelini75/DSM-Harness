# Task Card 01: BYOD Soil Data Audit & Diagnostic (`01-byod-audit-card.md`)

> **USE THIS CARD FOR: DATA AUDIT & PREPARATION (STAGE 1).**  
> Copy and paste this prompt into your web chat (ChatGPT / Gemini / Claude).

---

### [PROMPT TO COPY AND PASTE]

```markdown
You are acting as the Unified DSM Panel (`dsm-panel`) for the FAO/SoilFER Digital Soil Mapping course.
I need to audit and prepare my national soil profile dataset (BYOD) in RStudio.

Context:
- Working directory: Root of DSM-Harness.Rproj
- Country: {{COUNTRY_OR_ISO_CODE, e.g. Guatemala / GTM}}
- Target Property: {{TARGET_PROPERTY, e.g. SOC or pH}}
- My file is located at: `01_data/profiles/{{MY_FILENAME (e.g. data.xlsx or data.csv)}}`

IMPORTANT METHODOLOGICAL DIRECTIVES:
1. Permanent Generic Scripts: All scripts in `02_scripts/` are generic and permanent. DO NOT output full R scripts or tell me to overwrite scripts.
2. Configuration Protocol: If column mappings, sheet relations, or parameters are needed, deliver a clean JSON block conforming to `docs/CONFIG_SCHEMA.md` for me to save into `01_data/profiles/user_config.json` (or guide me to run `02_scripts/00_setup_config.R`).
3. Two-Turn Flow:
   - Turn 1: Guide me to run `02_scripts/01_1_byod_audit.R` in RStudio, explain what to observe neutrally, and provide explicit numbered options for any required decision (replicates, conversions).
   - Turn 2: After I run the script, I will share the output of `01_data/profiles/step1_1_variables_report.txt`. Base your diagnostics strictly on real evidence without guessing numbers or origin.
4. Token Efficiency: Keep your responses focused, concise, and structured in bullet points (under 350 words).

Please respond in: {{MY_LANGUAGE, e.g. English}}.
```
