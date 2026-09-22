# DSM-Harness: Digital Soil Mapping & Soil Spectroscopy AI Training Harness

🌐 **Idioma / Language**: **[Español]** | [English](README.md)

> **Arnés y Orquestador Asistido por IA para Cursos Presenciales de Mapeo Digital de Suelos (DSM) y Espectroscopía de Suelos (DRS).**

Este repositorio permite a los participantes de cursos presenciales de Mapeo Digital de Suelos y Espectroscopía generar código R reproducible, robusto y estandarizado mediante Inteligencia Artificial, actuando como **científicos de suelos y evaluadores críticos** sin trabarse en la sintaxis de programación.

El flujo de trabajo es modular y adaptable a cursos de distinta duración (3, 4 o 5 días), centrado en la resolución práctica de casos y la interpretación edafológica.

---

## 📖 Cómo usar este repositorio (Guía Paso a Paso para Principiantes)

Si nunca has usado GitHub o la terminal, sigue estos pasos en orden:

### Paso 1: Descargar el repositorio a tu computadora

Tienes dos formas de descargarlo. Elige **la Opción A** si no usas Git:

* **Opción A (Descarga directa en ZIP - Recomendada para principiantes):**
  1. En la parte superior de esta página en GitHub, haz clic en el botón verde que dice **`<> Code`**.
  2. En el menú que se despliega, haz clic en **`Download ZIP`**.
  3. Una vez descargado el archivo `DSM-Harness-main.zip` en tu carpeta de *Descargas*, haz clic derecho sobre él y selecciona **"Extraer todo..."** (o *Descomprimir*).
  4. Extrae los archivos en una carpeta de fácil acceso en tu disco local (por ejemplo en `C:\DSM-Harness` en Windows o en tu carpeta de `Documentos`). **Asegúrate de entrar en la carpeta extraída donde veas los archivos del proyecto.**

* **Opción B (Clonar con Git si ya tienes Git instalado):**
  Abre tu consola o terminal y ejecuta:
  ```bash
  git clone https://github.com/angelini75/DSM-Harness.git
  cd DSM-Harness
  ```

---

### Paso 2: Verificar tu entorno de R y RStudio

Antes de abrir RStudio, ejecutaremos un script que revisará automáticamente si tienes instalado R, RStudio y todas las librerías necesarias (`terra`, `sf`, `ranger`, `caret`, `Boruta`, `prospectr`, etc.).

* **Si estás en Windows:**
  1. Abre la carpeta donde descomprimiste el proyecto.
  2. Haz clic derecho en un espacio vacío dentro de la carpeta y elige **"Abrir en Terminal"** o **"Abrir ventana de PowerShell aquí"**.  
     *(O presiona la tecla Windows, escribe `PowerShell`, ábrelo y escribe `cd C:\Ruta\A\Tu\Carpeta\DSM-Harness`)*.
  3. Escribe el siguiente comando y presiona Enter:
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\check_environment.ps1
     ```
  4. El script comprobará tus programas e instalará automáticamente cualquier paquete de R faltante en tu biblioteca de usuario.

* **Si estás en macOS o Linux:**
  1. Abre la aplicación **Terminal**.
  2. Navega hasta la carpeta del proyecto (ejemplo: `cd ~/Documents/DSM-Harness`).
  3. Otorga permisos de ejecución y corre el script:
     ```bash
     chmod +x check_environment.sh
     ./check_environment.sh
     ```

---

### Paso 3: Abrir el Proyecto en RStudio

1. Ve a la carpeta del proyecto en el explorador de archivos.
2. Busca el archivo llamado **`DSM-Harness.Rproj`** y haz **doble clic** sobre él.
3. Se abrirá **RStudio**.
4. **¿Por qué es fundamental este paso?**  
   Al abrir el archivo `.Rproj`, RStudio fija automáticamente la carpeta del proyecto como tu directorio de trabajo (`getwd()`). Esto garantiza que todas las rutas relativas (`01_data/`, `02_scripts/`, `03_outputs/`) funcionen perfectamente sin que tengas que configurar rutas manuales.

---

### Paso 4: Elegir tu forma de trabajar con la IA

Elige **la Modalidad B** si vas a usar chats gratuitos en el navegador web:

#### Modalidad A: En un IDE con Asistente de IA (Antigravity, Cursor o VS Code)
Si cuentas con un entorno que soporte agentes de IA:
- El asistente leerá automáticamente las instrucciones de [`AGENTS.md`](AGENTS.md) y los roles especializados en la carpeta `agents/`.
- Puedes dialogar directamente en tu idioma solicitando tareas del flujo de trabajo (ej. *"Actúa como dsm-panel y audita mi archivo en 01_data/profiles/datos_nacionales.csv"*).

#### Modalidad B: En Chats Web Gratuitos (ChatGPT, Gemini o Claude)
Si utilizas la versión web gratuita de cualquier IA en tu navegador:
1. En esta misma carpeta del proyecto, entra a la subcarpeta **[`cards/es/`](cards/es/)** (o [`cards/en/`](cards/en/) para inglés).
2. Abre la tarjeta de texto correspondiente a la etapa en la que estés trabajando (por ejemplo, `01-byod-audit-card.md`).
3. Copia el bloque de texto del prompt.
4. Sustituye los valores entre llaves dobles (como `{{NOMBRE_DE_MI_ARCHIVO.csv}}` o `{{PROPIEDAD_OBJETIVO}}`) por los nombres reales de tus datos.
5. Pégalo en tu chat de IA web (ChatGPT, Gemini o Claude).
6. La IA te responderá con el código R listo para copiar y pegar en tu RStudio, acompañado de gráficos diagnósticos y preguntas edafológicas para interpretar.

> 💡 **Si un script te da error en RStudio**: No le pegues todo tu código a la IA. Abre **[`cards/es/00-error-rescue.md`](cards/es/00-error-rescue.md)**, pega solo el mensaje de error y las 4 líneas previas. Esto ahorra cuota de tokens y te da la solución en segundos.

---

## 🗺️ Flujo de Trabajo Modular (Las 5 Etapas)

El proceso está dividido en 5 etapas secuenciales e independientes de la duración del taller:

| Etapa | Módulo Metodológico | Tarjeta de Prompt | Objetivo Central |
| :--- | :--- | :--- | :--- |
| **00** | Rescate Express | [`cards/es/00-error-rescue.md`](cards/es/00-error-rescue.md) | **Depuración de Errores**: Diagnóstico rápido de 1 línea y snippet mínimo de corrección sin gastar cuota. |
| **01** | Auditoría de Datos | [`cards/es/01-byod-audit-card.md`](cards/es/01-byod-audit-card.md) | **Auditoría BYOD**: Validación de coordenadas, chequeo de horizontes/profundidades ISO 28258 y coherencia pedológica. |
| **02** | Covariables SCORPAN | [`cards/es/02-covariates-card.md`](cards/es/02-covariates-card.md) | **Extracción Espacial**: Inspección de rásteres ambientales, armonización de CRS y extracción puntual (`dat_cov`). |
| **03** | Espectroscopía de Suelos | [`cards/es/03-spectra-card.md`](cards/es/03-spectra-card.md) | **Espectroscopía DRS**: Preprocesamiento (`prospectr`: SNV, Savitzky-Golay), calibración quimiométrica y dataset aumentado. |
| **04** | Modelado Predictivo | [`cards/es/04-qrf-modeling-card.md`](cards/es/04-qrf-modeling-card.md) | **Quantile Regression Forest**: Selección con `Boruta`, entrenamiento con `ranger`/`caret`, métricas y gráfico 1:1. |
| **05** | Mapeo y Publicación | [`cards/es/05-prediction-opennsis-card.md`](cards/es/05-prediction-opennsis-card.md) | **Mapeo Espacial & OpenNSIS**: Predicción por mosaicos (media e incertidumbre), exportación a COG y metadatos ISO 19139. |

---

## 🏛️ Roles Disciplinares Definidos

El arnés separa las responsabilidades en 4 roles profesionales que pueden consultarse por separado o integrados en el panel:

- 💻 **`r-engineer` ([R Specialist](agents/r-engineer.md))**: Diseña código R limpio y seguro, siguiendo estrictamente el script de referencia oficial `02_scripts/reference_modelling_v2.R`.
- 🌍 **`geo-standards` ([Geospatial & OpenNSIS Architect](agents/geo-standards.md))**: Vela por proyecciones CRS, resoluciones, formato Cloud-Optimized GeoTIFF (COG con compresión DEFLATE y NoData `-9999`) y nombres de capa estandarizados.
- 📊 **`geostat-modeler` ([Geostatistician & Pedometrician](agents/geostat-modeler.md))**: Supervisa la selección de variables con Boruta, validación cruzada repetida, métricas ($R^2$, RMSE, CCC) e intervalos de incertidumbre.
- 🔬 **`soil-scientist` ([Pedologist & Soil Interpreter](agents/soil-scientist.md))**: Evalúa la coherencia agronómica y edafológica (relaciones carbono-densidad, pH-bases, plausibilidad geomorfológica del mapa) formulando preguntas guiadas al alumno.
- 👥 **`dsm-panel` ([Unified Panel](agents/dsm-panel.md))**: Modo unificado en un solo turno que entrega [1] Código R, [2] Chequeo espacial, [3] Puntos estadísticos a verificar y [4] Preguntas de reflexión pedológica.

---

## 🌐 Integración con OpenNSIS (UN-FAO)

Todos los productos generados por el arnés siguen las directrices de la Infraestructura de Datos Espaciales [OpenNSIS](https://github.com/un-fao/OpenNSIS) de la FAO / GloSIS:
- **Modelo de Perfiles**: Compatible con ISO 28258 (ver plantilla en `01_data/templates/opennsis_profile_template.csv`).
- **Nomenclatura Oficial**: `<PAIS>-<PROYECTO>-<PROPIEDAD>-<PROF_SUP>-<PROF_INF>-<ESTADISTICA>.tif`  
  *Ejemplo:* `GTM-SOILFER-SOC-0-30-mean.tif` y `GTM-SOILFER-SOC-0-30-sd.tif`.
- **Formato Ráster**: Cloud-Optimized GeoTIFF (COG), compresión `DEFLATE`, `predictor 2`, tiles de 512px y NoData `-9999`.
- **Metadatos**: Generación de archivo XML lateral según ISO 19139 para registro en catálogos pyCSW.
- **Doctrina No Bloqueante**: La falta de cumplimiento emite avisos pedagógicos (*advisories*), pero nunca detiene el modelado si un participante trae variables particulares.

---

## 📁 Estructura del Repositorio

```text
DSM-Harness/
├── .gitignore
├── DSM-Harness.Rproj                       # Proyecto RStudio
├── README.md                               # Guía en Inglés
├── README.es.md                            # Guía en Español (este archivo)
├── AGENTS.md                               # Índice maestro para agentes de IA
├── check_environment.ps1                   # Diagnóstico Windows (PowerShell)
├── check_environment.sh                    # Diagnóstico macOS / Linux (Bash)
│
├── 01_data/                                # Datos de entrada y plantillas
│   └── templates/                          # Plantilla CSV OpenNSIS ISO 28258
│
├── 02_scripts/                             # Scripts de referencia
│   ├── 00_check_packages.R                 # Validador de paquetes
│   ├── reference_modelling_v2.R            # Script oficial de referencia para modelado
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
│   ├── es/                                 # Tarjetas de prompt en Español
│   └── en/                                 # Tarjetas de prompt en Inglés
└── docs/                                   # Documentación técnica (PRD, contratos, OpenNSIS)
```

---

## 🔗 Repositorios de Referencia

- [OpenNSIS](https://github.com/un-fao/OpenNSIS) — Open National Soil Information System (FAO).
- [SoilFER-Training-Manual](https://github.com/SoilFER/SoilFER-Training-Manual) — Technical Manual for SoilFER Training.
- [SoilFER-Training-Resources](https://github.com/SoilFER/SoilFER-Training-Resources) — Code, scripts, and practice datasets for SoilFER Training.
