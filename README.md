# Análisis de la Red de Sonómetros en Bilbao

## Descripción del proyecto
Este proyecto tiene como objetivo realizar un **análisis integral de la red de sonómetros en Bilbao**, con el fin de comprender y caracterizar los niveles de ruido en diferentes áreas de la ciudad y explorar su relación con el tráfico. El análisis permitirá identificar patrones temporales y espaciales, zonas críticas y posibles correlaciones con la densidad de tráfico.

---

## Fuentes de datos

- **Sonómetros – Mediciones (JSON)**  
  [https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_mediciones.jsp?idioma=c&formato=json](https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_mediciones.jsp?idioma=c&formato=json)

- **Sonómetros – Ubicación (GeoJSON)**  
  [https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_ubicacion.jsp?idioma=c&formato=geojson](https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_ubicacion.jsp?idioma=c&formato=geojson)

- **Tráfico Bilbao (GeoJSON)**  
  [https://www.bilbao.eus/aytoonline/srvDatasetTrafico?formato=geojson](https://www.bilbao.eus/aytoonline/srvDatasetTrafico?formato=geojson)

---

## Objetivos del proyecto

1. Comprender y caracterizar los niveles de ruido en distintas zonas de Bilbao.
2. Explorar la relación entre el ruido ambiental y el tráfico.
3. Generar un **dashboard interactivo en Power BI** que integre visualizaciones geográficas, temporales y comparativas.

---

## Competencias técnicas y criterios de evaluación

### RA1: Adquisición y análisis de datos
- **Criterios de evaluación:**
  - Identificación de conceptos de matemática discreta, lógica algorítmica y complejidad computacional aplicada a datos.
  - Extracción automática de conocimiento de grandes volúmenes de datos.
  - Integración de diferentes fuentes y tipos de datos.
  - Construcción y relación de conjuntos de datos complejos.
  - Planificación, organización y secuenciación del proyecto.

### RA2: Cuadros de mando y visualización
- **Criterios de evaluación:**
  - Clasificación de librerías y técnicas de representación de información.
  - Cruce de información según el objetivo y la naturaleza de los datos.
  - Desarrollo de cuadros de mando con técnicas básicas.
  - Evaluación del impacto del análisis sobre los objetivos propuestos.

---

## Objetivos de aprendizaje

1. Seleccionar y usar lenguajes, herramientas y librerías para aplicaciones multiplataforma con acceso a bases de datos.
2. Gestionar información almacenada mediante sistemas de formularios e informes.
3. Manipular e integrar contenidos gráficos y multimedia en aplicaciones multiplataforma.
4. Desarrollar interfaces gráficas de usuario siguiendo especificaciones y verificando usabilidad.

---

## Metodología y tareas

1. **Comprensión y planificación del problema**
2. **Adquisición de datos**  
   - Descarga y lectura de JSON y GeoJSON usando R.
3. **Preparación y calidad del dato**  
   - Limpieza, tipado y tratamiento de valores faltantes o anómalos.  
   - Generación de un conjunto de datos final listo para análisis.
4. **Integración de fuentes**  
   - Relación de mediciones de sonómetros con ubicación y tráfico.
5. **Análisis exploratorio y extracción de conocimiento**
   - Caracterización por:
     - Zonas / sonómetros
     - Franjas horarias
     - Días laborales, festivos y fines de semana
   - Identificación de puntos con comportamiento diferencial.
6. **Preparación del modelo para BI**
7. **Desarrollo del cuadro de mando en Power BI**
   - Mínimo contenido:
     - Mapa o visual geográfico
     - Evolución temporal
     - Ranking/segmentación por zona o sensor
     - Visualizaciones de relación ruido–tráfico
     - Filtros e interactividad (fecha, zona/sensor, franja horaria)
8. **Conclusiones e impacto**
   - Interpretación de resultados basada en evidencias.
   - Identificación de limitaciones y mejoras futuras.

---

## Tecnologías y herramientas

- Lenguaje de análisis de datos: **R**
- Visualización y dashboard: **Power BI**
- Formatos de datos: **JSON, GeoJSON**
- Bibliotecas recomendadas: `tidyverse`, `sf`, `ggplot2`, `lubridate`

---

## Resultados esperados

- Conjunto de datos limpio y listo para análisis.
- Visualizaciones interactivas que muestren:
  - Patrones de ruido por zona y horario.
  - Evolución temporal de los niveles de ruido.
  - Comparación y correlación con datos de tráfico.
- Conclusiones que informen sobre zonas críticas y posibles medidas de mitigación.

---

## Conclusión

El proyecto permitirá una comprensión detallada de la **contaminación acústica en Bilbao** y su relación con el tráfico, proporcionando herramientas de visualización y análisis útiles para la toma de decisiones municipales y estudios urbanos.

