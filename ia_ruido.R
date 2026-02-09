# CARGA DE LIBRERÍAS
library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(sf)
library(ggplot2)

# Directorio de trabajo
getwd()

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
############################ TRÁFICO (BILBAO) - PRIORIDAD API ############################

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