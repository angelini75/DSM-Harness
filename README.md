# DSM-Harness: Digital Soil Mapping & Soil Spectroscopy AI Training Harness

> **Orquestador y Arnés Asistido por IA para Talleres Intensivos de Mapeo Digital de Suelos y Espectroscopía (FAO / SoilFER / Países del SICA).**

Este repositorio permite a los participantes de cursos intensivos de 3,5 días generar código R reproducible, robusto y estandarizado mediante Inteligencia Artificial, actuando como **científicos de suelos y evaluadores críticos** sin perder tiempo en la sintaxis básica de programación.

---

## 🚀 Inicio Rápido en 3 Pasos

### Paso 1: Verificar el Entorno Local de R y RStudio
Abre tu terminal en la carpeta del repositorio y ejecuta el script de diagnóstico correspondiente a tu sistema operativo:

- **En Windows (PowerShell):**
  ```powershell
  .\check_environment.ps1
  ```
- **En macOS o Linux (Terminal):**
  ```bash
  chmod +x check_environment.sh
  ./check_environment.sh
  ```
El script verificará que R y RStudio estén instalados y validará/instalará las librerías necesarias (`terra`, `sf`, `ranger`, `caret`, `Boruta`, `prospectr`, `mapview`, `tidyverse`, `aqp`).

### Paso 2: Abrir el Proyecto en RStudio
Haz doble clic en el archivo **`DSM-Harness.Rproj`**.  
Esto fija automáticamente la raíz del proyecto y asegura que todas las rutas relativas (`01_data/`, `02_scripts/`, `03_outputs/`) funcionen sin errores de ruta.

### Paso 3: Elegir tu Modalidad de Asistencia con IA

Tienes dos formas de trabajar según las herramientas que utilices:

#### Modalidad A: En tu IDE con IA (Antigravity, Cursor o VS Code)
Si usas un IDE asistido por IA, el asistente leerá automáticamente [`AGENTS.md`](AGENTS.md) y los roles especializados en `agents/`. Solo pídele lo que necesitas en tu idioma (ej. *"Actúa como dsm-panel y audita mis datos en 01_data/profiles/suelos_guatemala.csv"*).

#### Modalidad B: En Chats Web Gratuitos (ChatGPT, Gemini o Claude)
Si no tienes un IDE de IA o usas cuentas gratuitas web:
1. Abre la carpeta [`cards/`](cards/).
2. Abre la tarjeta correspondiente a la etapa del taller en la que estés.
3. Copia el bloque de texto, completa tus variables (ej. nombre de tu país o archivo) y pégalo en tu chat de IA web.
4. La IA te devolverá el script en R con salidas gráficas y preguntas de interpretación pedológica.

---

## 🗺️ Mapa de Trabajo de los 3,5 Días (Las 5 Etapas)

| Etapa | Sesión de la Agenda | Tarjeta de Prompt | Objetivo Central |
| :--- | :--- | :--- | :--- |
| **00** | Cualquier momento | [`cards/00-error-rescue.md`](cards/00-error-rescue.md) | **Rescate de Errores**: Diagnóstico rápido de 1 línea y snippet mínimo de corrección (ahorra tokens). |
| **01** | Día 1 PM / Día 2 AM | [`cards/01-byod-audit-card.md`](cards/01-byod-audit-card.md) | **Auditoría BYOD**: Validación de coordenadas en país, chequeo de horizontes/profundidades y matriz pedológica. |
| **02** | Día 2 PM | [`cards/02-covariates-card.md`](cards/02-covariates-card.md) | **Covariables Ambientales**: Inspección de rásteres SCORPAN, armonización de CRS y extracción de puntos (`dat_cov`). |
| **03** | Día 3 AM | [`cards/03-spectra-card.md`](cards/03-spectra-card.md) | **Espectroscopía DRS**: Preprocesamiento (`prospectr`: SNV, Savitzky-Golay), calibración y dataset aumentado. |
| **04** | Día 3 PM | [`cards/04-qrf-modeling-card.md`](cards/04-qrf-modeling-card.md) | **Modelado QRF**: Selección con `Boruta`, entrenamiento con `ranger`/`caret`, métricas `eval.RData` y gráfico 1:1. |
| **05** | Día 4 AM / PM | [`cards/05-prediction-opennsis-card.md`](cards/05-prediction-opennsis-card.md) | **Mapeo Espacial & OpenNSIS**: Predicción por mosaicos (media e incertidumbre), exportación a COG y metadatos ISO 19139. |

---

## 🏛️ Roles Disciplinares Definidos

El arnés separa las responsabilidades en 4 roles profesionales que pueden actuar por separado o integrados en el panel:

- 💻 **`r-engineer` ([R Specialist](agents/r-engineer.md))**: Diseña código R limpio y seguro, siguiendo estrictamente el script de referencia oficial `02_scripts/reference_modelling_v2.R`.
- 🌍 **`geo-standards` ([Geospatial & OpenNSIS Architect](agents/geo-standards.md))**: Vela por proyecciones CRS, resoluciones, formato Cloud-Optimized GeoTIFF (COG con compresión DEFLATE y NoData `-9999`) y nombres de capa estandarizados.
- 📊 **`geostat-modeler` ([Geostatistician & Pedometrician](agents/geostat-modeler.md))**: Supervisa la selección de variables con Boruta, validación cruzada repetida, métricas ($R^2$, RMSE, CCC) e intervalos de incertidumbre.
- 🔬 **`soil-scientist` ([Pedologist & Soil Interpreter](agents/soil-scientist.md))**: Evalúa la coherencia agronómica y edafológica (relaciones carbono-densidad, pH-bases, plausibilidad geomorfológica del mapa) formulando preguntas guiadas al alumno.
- 👥 **`dsm-panel` ([Unified Panel](agents/dsm-panel.md))**: Modo unificado en un solo turno que entrega [1] Código R, [2] Chequeo espacial, [3] Puntos estadísticos a verificar y [4] Preguntas de reflexión pedológica.

---

## 🌐 Integración con OpenNSIS (UN-FAO)

Todos los productos generados por el arnés siguen las directrices de la Infraestructura de Datos Espaciales **OpenNSIS / GloSIS** de la FAO:
- **Modelo de Perfiles**: Compatible con ISO 28258 (ver plantilla en `01_data/templates/opennsis_profile_template.csv`).
- **Nomenclatura Oficial**: `<PAIS>-<PROYECTO>-<PROPIEDAD>-<PROF_SUP>-<PROF_INF>-<ESTADISTICA>.tif`  
  *Ejemplo:* `GTM-SOILFER-SOC-0-30-mean.tif` y `GTM-SOILFER-SOC-0-30-sd.tif`.
- **Formato Ráster**: Cloud-Optimized GeoTIFF (COG), compresión `DEFLATE`, `predictor 2`, tiles de 512px y NoData `-9999`.
- **Metadatos**: Generación de archivo XML lateral según ISO 19139 para registro en catálogos pyCSW.
- **Doctrina No Bloqueante**: La falta de cumplimiento emite avisos pedagógicos (*advisories*), pero nunca detiene el modelado si un país trae variables particulares.

---

## 📁 Estructura del Repositorio

```text
DSM-Harness/
├── .gitignore
├── DSM-Harness.Rproj                       # Proyecto RStudio
├── README.md                               # Este instructivo
├── AGENTS.md                               # Índice maestro para agentes de IA
├── check_environment.ps1                   # Diagnóstico Windows (PowerShell)
├── check_environment.sh                    # Diagnóstico macOS / Linux (Bash)
│
├── 01_data/                                # Datos de entrada (Kansas y plantillas BYOD)
│   └── templates/                          # Plantilla CSV OpenNSIS ISO 28258
│
├── 02_scripts/                             # Scripts oficiales
│   ├── 00_check_packages.R                 # Validador de paquetes
│   ├── reference_modelling_v2.R            # Script oficial SoilFER Module 3
│   └── eval.RData                          # Función de cálculo de métricas
│
├── 03_outputs/                             # Carpetas de resultados
│   ├── module3/models/                     # Modelos guardados (.rds)
│   ├── module3/validation/                 # Métricas de validación (.csv)
│   ├── module3/tiles/                      # Mosaicos temporales
│   ├── module3/maps/                       # Mapas finales y metadatos XML
│   └── module3/figures/                    # Gráficos diagnósticos (Boruta, varImp, 1:1)
│
├── agents/                                 # Definiciones de los 4 roles + panel
├── skills/                                 # Habilidades procedimentales de DSM y DRS
├── cards/                                  # Tarjetas de prompts para copiar y pegar en web
└── docs/                                   # Documentación técnica (PRD, contratos, OpenNSIS)
```

---

## 👥 Créditos y Referencias

- **FAO SoilFER (Soil Fertility and Mapping Project)**: Manuales de entrenamiento y scripts de referencia (`SoilFER-Training-Manual`, `SoilFER-Training-Resources`).
- **Instructores**: Marcos Angelini & Leonardo Ramirez-Lopez (FAO).
- **Plataforma OpenNSIS**: ISRIC World Soil Information & UN-FAO GloSIS Federation.
- **Licencia**: MIT.
