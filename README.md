# 🔊 RuidoBilbao — Análisis de Ruido y Tráfico en Bilbao

Proyecto de análisis de datos que combina mediciones de ruido ambiental (sonómetros) con datos de tráfico en tiempo real de la ciudad de Bilbao, con el objetivo de estudiar la relación entre la intensidad del tráfico y los niveles de contaminación acústica.

---

## 📁 Estructura del proyecto

```
RuidoBilbao/
│
├── RuidoBilbao.R           # Script principal: carga, procesamiento, unión y análisis
├── unir.R                  # Script auxiliar: combina múltiples GeoJSONs de tráfico
├── dataset_exportado.csv   # Dataset final listo para Power BI u otras herramientas
├── traficoGEOJSON/
│   └── trafico_final.geojson   # Histórico acumulado de datos de tráfico
└── README.md
```

---

## 📊 Fuentes de datos

| Fuente | Tipo | URL / Descripción |
|---|---|---|
| Sonómetros - Mediciones | JSON | Open Data Ayuntamiento de Bilbao |
| Sonómetros - Ubicación | GeoJSON | Open Data Ayuntamiento de Bilbao |
| Tráfico en tiempo real | GeoJSON | Open Data Ayuntamiento de Bilbao |

Los datos se obtienen directamente desde las APIs del Ayuntamiento de Bilbao en cada ejecución del script.

---

## ⚙️ Requisitos

### R (versión ≥ 4.1 recomendada)

Instala las siguientes librerías antes de ejecutar:

```r
install.packages(c(
  "httr2",
  "jsonlite",
  "dplyr",
  "tidyr",
  "lubridate",
  "sf",
  "ggplot2"
))
```

---

## 🚀 Cómo ejecutar el proyecto

### 1. Preparación

Clona o descarga el repositorio y ajusta el directorio de trabajo en `RuidoBilbao.R`:

```r
setwd("C:/tu/ruta/RuidoBilbao")
```

### 2. (Opcional) Unir GeoJSONs históricos de tráfico

Si tienes múltiples archivos `.geojson` de tráfico descargados previamente, ejecútalos primero con el script auxiliar:

```r
source("unir.R")
```

Esto generará `traficoGEOJSON/trafico_final.geojson` con todo el histórico combinado.

### 3. Ejecutar el análisis principal

```r
source("RuidoBilbao.R")
```

El script realizará automáticamente:
1. Descarga y limpieza de mediciones de sonómetros
2. Descarga de ubicaciones georreferenciadas de los sonómetros
3. Descarga de datos de tráfico en tiempo real
4. Actualización del histórico de tráfico
5. Cruce espacial y temporal entre ruido y tráfico
6. Generación de gráficos de análisis exploratorio
7. Exportación del dataset final a `dataset_exportado.csv`

---

## 🔗 Metodología de cruce de datos

El cruce entre las mediciones de ruido y los datos de tráfico se realiza en dos pasos:

**1. Cruce espacial:** mediante `st_nearest_feature()` se asocia cada sonómetro al tramo de tráfico más cercano, identificado por `CodigoSeccion`.

**2. Cruce temporal:** las marcas de tiempo de ambas fuentes se redondean a intervalos de 15 minutos (`Clave_Tiempo`), permitiendo unir mediciones que no son exactamente simultáneas. La diferencia real en minutos queda registrada en la columna `Dif_Minutos_Real`.

---

## 📋 Dataset exportado (`dataset_exportado.csv`)

El archivo CSV final contiene **2.885 registros** y las siguientes columnas:

| Columna | Descripción |
|---|---|
| `Codigo` | Identificador del sonómetro |
| `Decibelios` | Nivel de ruido medido (dBA) |
| `FechaHora` | Fecha y hora de la medición de ruido |
| `Hora` | Hora del día (0–23) |
| `Dia` | Día de la semana |
| `serialNumber` | Número de serie del dispositivo |
| `status` | Estado del dispositivo |
| `address` | Dirección del sonómetro |
| `deviceTypeId` | Tipo de dispositivo |
| `longitude` / `latitude` | Coordenadas geográficas |
| `CodigoSeccion` | Identificador del tramo de tráfico asociado |
| `Clave_Tiempo` | Marca de tiempo redondeada a 15 min (clave de cruce) |
| `Intensidad` | Vehículos por hora |
| `Ocupacion` | Porcentaje de ocupación de la vía |
| `Velocidad` | Velocidad media (km/h) |
| `FechaHora_trafico` | Fecha y hora del dato de tráfico |
| `Dif_Minutos_Real` | Diferencia real en minutos entre ambas mediciones |

---

## 📈 Análisis exploratorio incluido

El script genera cuatro gráficos con `ggplot2`:

1. **Evolución horaria del ruido** — Comparativa entre días laborables y fines de semana
2. **Top 10 sonómetros más ruidosos** — Ranking por decibelios promedio
3. **Mapa de calor ruido × día × hora** — Intensidad media por franja horaria y día de la semana
4. **Correlación tráfico vs. ruido** — Dispersión con línea de tendencia y coeficiente de correlación

---

## 📤 Exportación a Power BI

El archivo `dataset_exportado.csv` está listo para importarse directamente en Power BI u otras herramientas de visualización. La columna de geometría espacial se elimina automáticamente en la exportación para garantizar compatibilidad.

---

## 📝 Notas

- El script acumula el histórico de tráfico en `trafico_final.geojson` en cada ejecución, añadiendo los datos nuevos sin duplicar los existentes.
- Se aplica `sf_use_s2(FALSE)` para evitar errores de geometría estricta en algunas versiones del paquete `sf`.
- Los registros sin datos de tráfico válidos (nulos en `Ocupacion`, `Intensidad` o `Velocidad`) se eliminan del dataset final.
