# Task Card 01: BYOD Soil Data Audit & Diagnostic (`01-byod-audit-card.md`)

> **USAR ESTA TARJETA PARA: AUDITORÍA Y PREPARACIÓN DE DATOS (ETAPA 1).**  
> Copia y pega este prompt en tu chat web (ChatGPT / Gemini / Claude).

---

### [PROMPT TO COPY AND PASTE]

```markdown
You are acting as the Unified DSM Panel (`dsm-panel`) for the FAO/SoilFER Digital Soil Mapping course.
I need to audit and prepare my national soil profile dataset (BYOD) in RStudio.

Context:
- Working directory: Root of DSM-Harness.Rproj
- Country: {{PAIS_O_CODIGO_ISO, ej: Guatemala / GTM}}
- Target Property: {{PROPIEDAD_OBJETIVO, ej: SOC o pH}}
- My file is located at: `01_data/profiles/{{NOMBRE_DE_MI_ARCHIVO (ej: datos.xlsx o datos.csv)}}`

IMPORTANT METHODOLOGICAL DIRECTIVES:
1. Data Scope: We only need the core variables for DSM (profile ID, coords, upper/lower depth, and target soil properties). Please discard extraneous survey columns (taxonomic classification, survey dates, morphological descriptions, etc.).
2. Incremental Flow: Do NOT provide a long monolithic script. First, provide ONLY a short script for "Paso 1.1: Identificación y Confirmación de Variables".
3. The script should read the file, select relevant columns, and print a clear comparison table in the R console showing `[Original Column] ---> [Standard ISO 28258 Column]`.
4. Then, wait for my confirmation in the chat to tell you if the detected variables are correct or need adjustment, before providing the subsequent validation checks (spatial coordinates and depths).

Please respond in: {{MI_IDIOMA, ej: Español}}.
```
