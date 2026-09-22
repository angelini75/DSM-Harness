# DSM-Harness: Digital Soil Mapping & Soil Spectroscopy AI Training Harness

🌐 **Idioma / Language**: **[Español]** | [English](README.md)

> **Arnés y Orquestador Asistido por IA para Cursos Presenciales de Mapeo Digital de Suelos (DSM) y Espectroscopía de Suelos (DRS).**

Este repositorio permite a los participantes de cursos presenciales de Mapeo Digital de Suelos y Espectroscopía generar código R reproducible, robusto y estandarizado mediante Inteligencia Artificial, actuando como **científicos de suelos y evaluadores críticos** sin trabarse en la sintaxis de programación.

El flujo de trabajo es modular y adaptable a cursos de distinta duración (3, 4 o 5 días), centrado en la resolución práctica de casos y la interpretación edafológica.

---

> 💡 **Optimizado para usuarios sin suscripciones pagas de IA**  
> Todo el arnés, las instrucciones de los agentes y las tarjetas de prompts fueron **especialmente diseñados para participantes que NO cuentan con cuentas pagas** (como ChatGPT Plus, Claude Pro o Gemini Advanced).  
> Los prompts son atómicos, directos y de bajísimo consumo de tokens, garantizando que puedas completar todo el taller usando las **cuotas y versiones gratuitas** de Gemini, ChatGPT, Claude o Antigravity sin que se agoten tus límites por hora o por día.

---

## 🎯 Alcance de los Datos: ¿Qué variables necesita el arnés?

Este arnés está diseñado **exclusivamente para el flujo de modelado espacial (DSM) y espectroscopía de suelos (DRS)**. **No pretende ser una base de datos exhaustiva para almacenar todos los atributos de un sistema nacional de suelos**.

Los archivos de perfiles nacionales frecuentemente contienen decenas de columnas accesorias (clasificación taxonómica, fechas de muestreo, descripción morfológica de campo, geomorfología, uso actual, etc.). **Para el propósito del modelado predictivo en este curso, esas variables no tienen relevancia y son descartadas automáticamente** en la etapa de preparación.

El arnés se enfoca únicamente en el núcleo mínimo de variables necesarias para el mapeo digital:
1. **Identificador del perfil** (`profile_code` / `id_perfil`).
2. *(Opcional)* **Designación de horizonte o capa** (`Horizon` / `horizonte`).
3. **Límites de profundidad** (`upper` / `desde` / límite superior, y `lower` / `hasta` / límite inferior).
4. **Coordenadas geográficas** en WGS84 (`longitude` y `latitude`).
5. **Propiedades edafológicas analíticas clave a modelar** (ej: `SOC` / Carbono Orgánico, `pH_H2O`, `Clay`, `Sand`, `Silt`, `BD` / Densidad Aparente, `CEC`).

---

## 🔄 Flujo Metodológico: Validación Incremental por Criterios (Paso a Paso)

Para evitar la saturación, scripts inmanejables y consumo desmedido de tokens, **el arnés NO genera scripts monolíticos largos que pretendan resolver todo a la vez**:

1. **La IA asume que las cosas pueden salir mal**: Los nombres de columnas en bases de datos nacionales son muy diversos, pueden contener abreviaturas locales o significar cosas distintas según la institución.
2. **Ciclo interactivo criterio por criterio**:
   - **Paso 1.1 (Confirmación de variables)**: La IA entrega un script muy corto y conciso cuyo único fin es leer el archivo, seleccionar las columnas relevantes, mostrar una tabla comparativa clara en la consola de RStudio y pedir confirmación al alumno.
   - **Espera de retroalimentación**: El alumno ejecuta ese bloque breve en RStudio y responde en el chat si el mapeo fue acertado o qué corrección debe aplicarse.
   - **Siguientes criterios**: Solo una vez confirmadas las variables, se avanza a la validación espacial de coordenadas (Paso 1.2) y luego a la validación de profundidades y consistencia edafológica (Paso 1.3).

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

## 🤖 Cómo interactuar con la Inteligencia Artificial

Tienes dos formas de utilizar el arnés según tu entorno de trabajo:

### Opción A: Cómo usar este repositorio en Google Antigravity (o IDEs con IA)

Si utilizas **Google Antigravity** (o un editor con agentes como Cursor o VS Code con extensiones de IA):

1. **Abrir el espacio de trabajo**: En Antigravity, ve a `File -> Open Folder` y selecciona la carpeta raíz `DSM-Harness`.
2. **Detección automática**: Antigravity detectará automáticamente el archivo [`AGENTS.md`](AGENTS.md) como constitución del proyecto, reconociendo de inmediato:
   - Los 4 roles especializados en la carpeta `agents/` (`r-engineer`, `geo-standards`, `geostat-modeler`, `soil-scientist`) y el modo colegiado `dsm-panel`.
   - Las reglas procedimentales en `skills/`.
   - El script oficial de referencia en `02_scripts/reference_modelling_v2.R`.
3. **Cómo dialogar con el asistente**:
   Simplemente escribe en el panel de chat en lenguaje natural (en español o inglés). Por ejemplo:
   - *"Actúa como dsm-panel y ayúdame a auditar mi archivo de perfiles en 01_data/profiles/mis_datos.csv"*.
   - *"Actúa como r-engineer y genera el script para extraer covariables a mis puntos"*.
   - *"Actúa como geostat-modeler y revisa si este scatterplot 1:1 muestra sobreajuste"*.
   - *"Actúa como soil-scientist y dime si estas relaciones entre carbono y densidad aparente son físicamente plausibles"*.
4. **Perfilado estructural, generación de script a medida y ejecución en RStudio**:
   - **Inspección sin adivinanzas**: Cuando indiques la ruta a tu archivo (ej: `01_data/profiles/Profiles_data.xlsx`), Antigravity ejecutará un perfilador liviano (`02_scripts/inspect_dataset.py`) que lee todas las hojas del Excel, extrae los nombres reales de las columnas, identifica claves relacionales (ej. `id_perfil` uniendo sitios con horizontes) y examina valores de muestra.
   - **Script hecho a medida**: Con la estructura real descubierta, la IA escribe directamente un script de R adaptado a tus datos en `02_scripts/01_byod_audit.R` (incorporando la unión de hojas con `left_join` si es un Excel relacional).
   - **Regla estricta sin procesamiento pesado en terminal**: La IA solo realiza la inspección rápida de metadatos; nunca ejecuta la limpieza pesada ni cálculos espaciales en tu terminal, protegiendo tus tokens y tu entorno.
   - **Tu rol como científico**: Abre el archivo `.R` generado en tu RStudio (que ya tiene abierto `DSM-Harness.Rproj`), ejecútalo línea por línea, verifica la tabla en la consola y confirma o ajusta en el chat para avanzar al siguiente criterio.

---

### Opción B: Cómo usar este repositorio con Chats Web Gratuitos (ChatGPT, Gemini, Claude)

Si **no** tienes Antigravity ni un IDE de IA, puedes usar cualquier chat gratuito en tu navegador web (Google Gemini, ChatGPT, Claude, Copilot o Perplexity) sin pagar suscripciones:

1. **Abrir tu chat web**: Abre tu navegador e ingresa a tu chat de IA gratuito preferido (ej. [Gemini](https://gemini.google.com), [ChatGPT](https://chat.openai.com) o [Claude](https://claude.ai)).
2. **Localizar las Tarjetas de Prompt**: En la carpeta del proyecto, entra a **[`cards/es/`](cards/es/)** (o [`cards/en/`](cards/en/) si prefieres trabajar en inglés).
3. **Seleccionar la etapa**: Abre con cualquier visor de texto o bloc de notas la tarjeta correspondiente a lo que vas a realizar (ej. `01-byod-audit-card.md` para auditar datos, o `04-qrf-modeling-card.md` para entrenar el modelo).
4. **Completar tus variables**:
   Copia el bloque bajo el título `[PROMPT TO COPY AND PASTE]` y sustituye los campos entre llaves dobles por tus datos reales:
   - `{{NOMBRE_DE_MI_ARCHIVO.csv}}` $\rightarrow$ el nombre de tu archivo en `01_data/profiles/`.
   - `{{PROPIEDAD_OBJETIVO}}` $\rightarrow$ la variable a mapear (ej. `SOC` o `pH`).
   - `{{PAIS_O_CODIGO_ISO}}` $\rightarrow$ tu país (ej. `Guatemala` o `GTM`).
5. **Pegar en el chat web**: Envía el prompt. La IA te devolverá una respuesta estructurada con:
   - El bloque de código R listo para correr en tu RStudio.
   - La llamada obligatoria a generar un gráfico (`mapview`, `ggplot2` o Viridis).
   - 2 o 3 preguntas de reflexión pedológica para que interpretes el resultado visual.
6. **Copiar y ejecutar en RStudio**: Pega el código en tu consola de RStudio o en un script dentro de `02_scripts/` y ejecútalo.

> 🚨 **REGLA DE ORO PARA ERRORES (Ahorro de Cuota Gratuita)**:  
> Si un script te arroja un error en la consola de RStudio, **JAMÁS pegues todo tu script de 200 líneas en el chat web** (eso agotará tu cuota de tokens en pocos turnos).  
> En su lugar, abre **[`cards/es/00-error-rescue.md`](cards/es/00-error-rescue.md)**, copia esa plantilla y pega **únicamente el mensaje de error en rojo y las 4 líneas de código anteriores**.  
> La IA tiene la instrucción estricta de darte un diagnóstico de 1 sola línea y el bloque mínimo corregido de 2 a 5 líneas, resolviendo tu error al instante sin gastar tokens.

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
