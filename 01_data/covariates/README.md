# Guía de Covariables Ambientales (SCORPAN) para DSM-Harness

Este directorio (`01_data/covariates/`) o el subdirectorio de tu proyecto (`projects/<nombre>/covariates/`) almacena los rásters de covariables ambientales requeridos para las **Etapas 2, 3 y 4** de Mapeo Digital de Suelos.

---

## 1. Requisitos Técnicos de las Covariables

Para garantizar una extracción fluida y libre de desbordes de memoria durante el modelado y la predicción espacial:

1. **Formato**:
   - Archivos GeoTIFF (`.tif` o `.tiff`), ya sea como un archivo multibanda (stack) o múltiples archivos individuales de una banda.
2. **Sistema de Referencia de Coordenadas (CRS)**:
   - Debe tener un CRS definido en los metadatos GDAL (proyección métrica oficial de tu país, p. ej. UTM, o WGS84 EPSG:4326).
   - Los scripts del arnés proyectan automáticamente los perfiles de suelo al CRS del ráster antes de la extracción.
3. **Alineación Espacial (Co-registro)**:
   - Todas las capas deben compartir exactamente la **misma extensión espacial (bounding box), tamaño de píxel (resolución) y punto de origen**.
4. **Valores Sin Datos (NoData)**:
   - Debe tener asignado un valor NoData explícito (típicamente `-9999` o `NA`).

---

## 2. Tipos de Covariables Sugeridas (Marco SCORPAN)

* **Relieve / Topografía ($r$)**:
  - Modelo Digital de Elevación (DEM): Elevación, Pendiente (Slope), Orientación (Aspect), Índice de Humedad Topográfica (TWI), Posición Topográfica (TPI), Rugosidad.
* **Clima ($c$)**:
  - Precipitación media anual, temperatura media anual, estacionalidad bioclimática (WorldClim, CHELSA).
* **Organismos / Vegetación ($o$)**:
  - Series temporales o compuestos de NDVI, EVI, cobertura arbórea (Sentinel-2, Landsat, MODIS).
* **Material Parental / Geología ($p$)**:
  - Índices espectrales de arcillas, óxidos de hierro, radiometría gamma o litología categórica.

---

## 3. ¿Cómo usarlas en tu proyecto?

1. Coloca tus archivos `.tif` directamente en `projects/<nombre>/covariates/`.
2. O bien, declara la ruta a tu pila de covariables en `projects/<nombre>/config.json`:
   ```json
   {
     "covariates_path": "projects/mi_pais/covariates/covariables_stack_250m.tif"
   }
   ```
3. Ejecuta en RStudio:
   ```r
   source("projects/<nombre>/run_step.R")
   run_step("2")
   ```
