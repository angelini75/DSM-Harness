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
1. Data Scope: We only need core variables for DSM (profile ID, coords, upper/lower depth, and target soil properties). Please discard extraneous survey columns (taxonomic classification, survey dates, morphological descriptions, etc.).
2. Incremental Flow: Do NOT provide a long monolithic script. First, provide ONLY a short script for "Step 1.1: Variable Identification & Confirmation".
3. The script should read the file, select relevant columns, and print a clear comparison table in the R console showing `[Original Column] ---> [Standard ISO 28258 Column]`.
4. Then, wait for my confirmation in the chat to tell you if the detected variables are correct or need adjustment, before providing the subsequent validation checks (spatial coordinates and depths).

Please respond in: {{MY_LANGUAGE, e.g. English}}.
```
