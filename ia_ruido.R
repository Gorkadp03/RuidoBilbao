# CARGA DE LIBRERÍAS
library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(sf)
library(ggplot2)

# Directorio de trabajo
setwd("C:/Users/iabd/Desktop/RuidoBilbao")
directorio <- getwd()

############################ SONÓMETRO: MEDICIONES ############################

# URL del GeoJSON de sonometro_mediciones
url_sonometro_mediciones <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_mediciones.jsp?idioma=c&formato=json"

# Leer JSON desde la web
sonometro_mediciones <- fromJSON(url_sonometro_mediciones)

# Crear el dataframe de Sonometro_mediciones
sonometro_mediciones_df <- data.frame(
  Codigo = as.character(sonometro_mediciones$nombre_dispositivo),
  Decibelios = as.numeric(sonometro_mediciones$decibelios),
  FechaHora = as.POSIXct(sonometro_mediciones$fecha_medicion, format="%Y-%m-%d %H:%M:%OS"),
  stringsAsFactors = FALSE
)

# Revisar nulos y duplicadas
colSums(is.na(sonometro_mediciones_df))
sum(duplicated(sonometro_mediciones_df))

# Extraer información adicional (Hora y Día)
sonometro_mediciones_df$Hora <- format(sonometro_mediciones_df$FechaHora, "%H")
sonometro_mediciones_df$Dia <- weekdays(sonometro_mediciones_df$FechaHora)

# Mostrar ( Mínimo, Primer cuartil, Mediana, Promedio, Tercer cuartil, Máximo )
summary(sonometro_mediciones_df$Decibelios)

# Mostrar la desviación Estándar
sd(sonometro_mediciones_df$Decibelios)

# Revisar  clases
class(sonometro_mediciones_df)

# Mostrar primeras lineas
head(sonometro_mediciones_df)

############################ SONÓMETRO: UBICACIÓN ############################

# URL del GeoJSON de sonometro_ubicacion
url_sonometro_ubicacion <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_ubicacion.jsp?idioma=c&formato=geojson"

# Leer el GeoJSON como objeto sf
sonometro_ubicacion_sf <- st_read(url_sonometro_ubicacion, quiet = TRUE)

# Revisar nulos en el dataframe
colSums(is.na(sonometro_ubicacion_sf))

# Revisar duplicadas en el dataframe  
sum(duplicated(sonometro_ubicacion_sf))

# Revisar  clases
class(sonometro_ubicacion_sf)

# Mostrar primeras lineas
head(sonometro_ubicacion_sf)

############################ UNIÓN DE MEDICIONES CON UBICACIÓN ############################

# Asegúrate de que sonometro_ubicacion_sf tenga la columna geometry activa
sonometros_sf <- sonometro_mediciones_df %>%
  inner_join(sonometro_ubicacion_sf, by = c("Codigo" = "name")) %>% # inner_join para eliminar los que no tengan ubicación
  st_as_sf() # Esto funcionará SOLO si la columna 'geometry' sobrevivió al join.

# Eliminar registros sin geometría válida
sonometros_sf <- sonometros_sf[!is.na(st_dimension(sonometros_sf)), ]

head(sonometros_sf)

############################ TRÁFICO  ############################

# --- 1. CONFIGURACIÓN ---
url_trafico <- "https://www.bilbao.eus/aytoonline/srvDatasetTrafico?formato=geojson"
ruta_trafico_local <- "traficoGEOJSON/trafico_final.geojson"

sf_use_s2(FALSE) # Apagar geometría estricta

# --- 2. PASO 1: CREAR CON DATOS DEL ENLACE (LO NUEVO) ---
trafico_sf <- st_read(url_trafico, quiet = TRUE) %>%
  mutate(
    FechaHora = ymd_hms(FechaHora), # Aseguramos formato fecha
    Intensidad = as.numeric(Intensidad),
    Ocupacion = as.numeric(Ocupacion),
    Velocidad = as.numeric(Velocidad)
  ) %>%
  select(CodigoSeccion, Intensidad, Ocupacion, Velocidad, FechaHora, geometry)

# --- 3. PASO 2: AÑADIR LOS DEL ARCHIVO (EL HISTÓRICO) ---
if (file.exists(ruta_trafico_local)) {
  # CAMBIO REALIZADO: Ahora usamos 'trafico_historico'
  trafico_historico <- st_read(ruta_trafico_local, quiet = TRUE)
  
  # TRUCO IMPORTANTE: El histórico guardado suele tener nombre "FechaHora_trafico".
  # Para poder unirlo con el nuevo (que tiene "FechaHora"), hay que renombrarlo temporalmente.
  if ("FechaHora_trafico" %in% names(trafico_historico)) {
    trafico_historico <- trafico_historico %>% rename(FechaHora = FechaHora_trafico)
  }
  
  # Aseguramos que tengan las mismas columnas antes de pegar
  cols_comunes <- intersect(names(trafico_sf), names(trafico_historico))
  
  # UNIÓN: Ponemos el nuevo arriba y el histórico debajo
  trafico_sf <- rbind(trafico_sf[, cols_comunes], trafico_historico[, cols_comunes])
  
}

# Revisar nulos en el dataframe
colSums(is.na(trafico_sf))

# Revisar duplicadas en el dataframe  
sum(duplicated(trafico_sf))

# --- 4. LIMPIEZA FINAL TRAS LA UNIÓN ---
# Eliminamos duplicados si se solapan fechas y renombramos para el cruce posterior
trafico_sf <- trafico_sf %>%
  st_make_valid() %>%
  distinct(CodigoSeccion, FechaHora, .keep_all = TRUE) %>%
  rename(FechaHora_trafico = FechaHora)

# Revisar  clases
class(trafico_sf)

# Verificamos
head(trafico_sf)

# --- 5. GUARDAR  ---
st_write(trafico_sf, ruta_trafico_local, delete_dsn = TRUE, quiet = TRUE)

############################ UNIÓN OPTIMIZADA RUIDO-TRÁFICO ############################

# --- PASO 1: Unión Espacial ---
# Preparamos los tramos de tráfico (solo ubicación)
trafico_tramos_unicos <- trafico_sf %>% 
  distinct(CodigoSeccion, .keep_all = TRUE) %>% 
  select(CodigoSeccion, geometry)

# AQUÍ ESTABA EL ERROR: Usamos 'sonometros_sf' que es la variable que tú tienes creada
idx <- st_nearest_feature(sonometros_sf, trafico_tramos_unicos)

# Asignamos el código de la calle al sonómetro
sonometros_sf$CodigoSeccion <- trafico_tramos_unicos$CodigoSeccion[idx]

# --- PASO 2: Preparar claves de tiempo para el cruce ---
# Redondeamos la hora a los 15 minutos más cercanos en AMBAS tablas

# Usamos 'sonometros_sf'
sonometros_sf <- sonometros_sf %>%
  mutate(Clave_Tiempo = round_date(FechaHora, unit = "15 minutes"))

trafico_sf_clean <- trafico_sf %>%
  st_drop_geometry() %>% # Soltamos geometría para que el cruce sea rápido
  mutate(Clave_Tiempo = round_date(FechaHora_trafico, unit = "15 minutes")) %>%
  distinct(CodigoSeccion, Clave_Tiempo, .keep_all = TRUE) # Evitar duplicados

# --- PASO 3: Join Directo (Más rápido y ligero) ---
# Ahora unimos por CALLE y por HORA APROXIMADA a la vez.
sonometros_final <- sonometros_sf %>%
  inner_join(trafico_sf_clean, 
             by = c("CodigoSeccion" = "CodigoSeccion", 
                    "Clave_Tiempo" = "Clave_Tiempo"))

# --- PASO 4: Verificación y Limpieza ---
# Calculamos la diferencia real para asegurarnos
sonometros_final <- sonometros_final %>%
  mutate(Dif_Minutos_Real = abs(as.numeric(difftime(FechaHora, FechaHora_trafico, units = "mins"))))

# Limpieza final de nulos en datos de tráfico
sonometros_final <- sonometros_final %>%
  drop_na(Ocupacion, Intensidad, Velocidad)

# --- PASO 5: GUARDAR EL DATASET FINAL INTEGRADO ---



############################ UNIÓN FINAL: RUIDO Y TRÁFICO ############################

# --- PASO 1: Encontrar la calle (Tramo) más cercana a cada sonómetro ---
# Preparamos los tramos de tráfico únicos (solo para calcular distancias)
trafico_tramos_unicos <- trafico_sf %>% 
  distinct(CodigoSeccion, .keep_all = TRUE) %>% 
  select(CodigoSeccion, geometry)

# Buscamos el índice del tramo más cercano para cada sonómetro
# Usamos 'sonometros_sf' que es tu variable correcta
idx <- st_nearest_feature(sonometros_sf, trafico_tramos_unicos)

# Asignamos el ID de la calle (CodigoSeccion) al sonómetro
sonometros_sf$CodigoSeccion <- trafico_tramos_unicos$CodigoSeccion[idx]

# --- PASO 2: Sincronización Temporal (Redondeo a 15 min) ---
# Redondeamos la hora del SONÓMETRO
sonometros_sf <- sonometros_sf %>%
  mutate(Clave_Tiempo = round_date(FechaHora, unit = "15 minutes"))

# Redondeamos la hora del TRÁFICO y preparamos la tabla para el cruce
# Usamos st_drop_geometry() para aligerar antes del join
trafico_sf_clean <- trafico_sf %>%
  st_drop_geometry() %>% 
  mutate(Clave_Tiempo = round_date(FechaHora_trafico, unit = "15 minutes")) %>%
  distinct(CodigoSeccion, Clave_Tiempo, .keep_all = TRUE) # Evitar duplicados

# --- PASO 3: Join Definitivo (Espacial + Temporal) ---
# Unimos por: Mismo tramo de calle (CodigoSeccion) Y Mismo momento (Clave_Tiempo)
dataset_final <- sonometros_sf %>%
  inner_join(trafico_sf_clean, 
             by = c("CodigoSeccion" = "CodigoSeccion", 
                    "Clave_Tiempo" = "Clave_Tiempo"))

# --- PASO 4: Limpieza y Validación ---
# (Opcional) Calculamos la diferencia real en minutos
dataset_final <- dataset_final %>%
  mutate(Dif_Minutos_Real = abs(as.numeric(difftime(FechaHora, FechaHora_trafico, units = "mins"))))

# Eliminamos filas que no tengan datos de tráfico válidos (nulos)
dataset_final <- dataset_final %>%
  drop_na(Ocupacion, Intensidad, Velocidad)

###########################################
# --- PASO 5: EXPORTAR SOLO A CSV (PARA POWER BI) ---

# Preparamos la tabla quitando la columna "geometry" que molesta en el CSV
dataset_exportado <- dataset_final %>%
  st_drop_geometry()

# Guardamos el archivo CSV definitivo con el nombre que pediste
write.csv(dataset_exportado, "dataset_exportado.csv", row.names = FALSE, fileEncoding = "UTF-8")

# Verificamos las primeras filas
head(dataset_exportado)


############################## Analisis exploratorio ############################

# Aseguramos que dataset_final esté cargado y listo
analisis_df <- dataset_final %>%
  mutate(
    Hora_Num = hour(Clave_Tiempo),
    Dia_Semana = wday(Clave_Tiempo, label = TRUE, abbr = FALSE, week_start = 1),
    Tipo_Dia = ifelse(wday(Clave_Tiempo, week_start = 1) %in% c(6, 7), "Fin de Semana", "Laborable"),
    Franja = case_when(
      Hora_Num >= 7 & Hora_Num < 19 ~ "Diurno",
      Hora_Num >= 19 & Hora_Num < 23 ~ "Tarde",
      TRUE ~ "Nocturno"
    )
  )

############################## Gráfico 1 ############################
# Gráfico de evolución horaria promedio (Laborable vs Finde)
resumen_horario <- analisis_df %>%
  group_by(Hora_Num, Tipo_Dia) %>%
  summarise(
    Ruido_Medio = mean(Decibelios, na.rm = TRUE),
    Trafico_Medio = mean(Intensidad, na.rm = TRUE),
    .groups = 'drop'
  )

ggplot(resumen_horario, aes(x = Hora_Num, y = Ruido_Medio, color = Tipo_Dia)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  theme_minimal() +
  labs(
    title = "Evolución del Ruido Promedio por Hora",
    subtitle = "Comparativa Laborable vs. Fin de Semana",
    x = "Hora del día",
    y = "Decibelios (dBA)",
    color = "Tipo de Día"
  ) +
  scale_x_continuous(breaks = seq(0, 23, 2))

############################## Gráfico 2 ############################
# Top 10 Sonómetros más ruidosos
top_ruido <- analisis_df %>%
  group_by(Codigo) %>% # O usa 'Direccion' si la tienes en el join
  summarise(
    Ruido_Promedio = mean(Decibelios, na.rm = TRUE),
    Ruido_Max = max(Decibelios, na.rm = TRUE)
  ) %>%
  arrange(desc(Ruido_Promedio)) %>%
  head(10)

ggplot(top_ruido, aes(x = reorder(Codigo, Ruido_Promedio), y = Ruido_Promedio)) +
  geom_col(fill = "firebrick") +
  coord_flip() + # Girar para leer mejor las etiquetas
  theme_minimal() +
  labs(
    title = "Top 10 Sonómetros con Mayor Ruido Promedio",
    x = "Sonómetro / Ubicación",
    y = "Decibelios Promedio"
  )

############################## Gráfico 3  ############################
# 1. Preparamos los datos resumidos
heatmap_data <- analisis_df %>%
  group_by(Dia_Semana, Hora_Num) %>%
  summarise(Ruido_Medio = mean(Decibelios, na.rm = TRUE), .groups = 'drop')

# 2. Generamos el Mapa de Calor
ggplot(heatmap_data, aes(x = Hora_Num, y = Dia_Semana, fill = Ruido_Medio)) +
  geom_tile(color = "white") + # Bordes blancos para separar
  scale_fill_viridis_c(option = "magma", direction = -1) + # Paleta de color profesional (requiere instalar o usar default)
  # Si no tienes viridis, usa: scale_fill_gradient(low = "green", high = "red") +
  theme_minimal() +
  labs(
    title = "Mapa de Calor del Ruido en Bilbao",
    subtitle = "Intensidad media por día y hora",
    x = "Hora del día",
    y = "Día de la semana",
    fill = "dBA"
  ) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  coord_fixed() # Para que los cuadrados sean proporcionales

############################## Gráfico 4 ############################
# Correlación: Intensidad de Tráfico vs. Nivel de Ruido
analisis_df$Intensidad <- as.numeric(as.character(analisis_df$Intensidad))
analisis_df$Decibelios <- as.numeric(as.character(analisis_df$Decibelios))

# 2. Gráfico de dispersión
ggplot(analisis_df, aes(x = Intensidad, y = Decibelios)) +
  geom_point(alpha = 0.1, color = "darkgreen") + # Alpha bajo porque habrá miles de puntos
  geom_smooth(method = "lm", color = "red", se = FALSE) + # Línea de tendencia
  theme_minimal() +
  labs(
    title = "Correlación: Tráfico vs. Ruido",
    subtitle = paste("Coeficiente de Correlación:", 
                     round(cor(analisis_df$Intensidad, analisis_df$Decibelios, use="complete.obs"), 3)),
    x = "Intensidad de Tráfico (Vehículos/hora)",
    y = "Decibelios (dBA)"
  )