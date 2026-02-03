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
sonometros_mediciones_df <- data.frame(
  Codigo = as.character(sonometro_mediciones$nombre_dispositivo),
  Decibelios = as.numeric(sonometro_mediciones$decibelios),
  FechaHora = as.POSIXct(sonometro_mediciones$fecha_medicion, format="%Y-%m-%d %H:%M:%OS"),
  stringsAsFactors = FALSE
)

# Revisar nulos y duplicadas
colSums(is.na(sonometros_mediciones_df))
sum(duplicated(sonometros_mediciones_df))

# Extraer información adicional (Hora y Día)
sonometros_mediciones_df$Hora <- format(sonometros_mediciones_df$FechaHora, "%H")
sonometros_mediciones_df$Dia <- weekdays(sonometros_mediciones_df$FechaHora)

# Mostrar ( Mínimo, Primer cuartil, Mediana, Promedio, Tercer cuartil, Máximo )
summary(sonometros_mediciones_df$Decibelios)

# Mostrar la desviación Estándar
sd(sonometros_mediciones_df$Decibelios)

# Revisar  clases
class(sonometros_mediciones_df)

# Mostrar primeras lineas
head(sonometros_mediciones_df)

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


############################ TRÁFICO (MODIFICADO: CARGA LOCAL) ############################

# URL del GeoJSON de tráfico
url_trafico <- "https://www.bilbao.eus/aytoonline/srvDatasetTrafico?formato=geojson"

# Ruta relativa correcta para tu estructura
ruta_trafico_local <- "traficoCSV/trafico_final.geojson"

# Leer el GeoJSON como objeto sf (dataframe con geometría)
trafico_sf <- sf::st_read(url_trafico, quiet = TRUE)

# 1. Normalizamos los datos de la API (Sobreescribimos trafico_sf para ahorrar variables)
# Convertimos texto a números/fechas para poder unirlos con el local
trafico_sf <- trafico_sf %>%
  mutate(
    FechaHora = ymd_hms(FechaHora),
    Intensidad = as.numeric(Intensidad),
    Ocupacion = as.numeric(Ocupacion),
    Velocidad = as.numeric(Velocidad)
  ) %>%
  select(CodigoSeccion, Intensidad, Ocupacion, Velocidad, FechaHora, geometry)

# 2. Carga y Normalización del Fichero LOCAL
if(file.exists(ruta_trafico_local)) {
  
  # Leemos y limpiamos el local igual que la API
  trafico_local <- st_read(ruta_trafico_local, quiet = TRUE) %>%
    mutate(
      FechaHora = ymd_hms(FechaHora),
      Intensidad = as.numeric(Intensidad),
      Ocupacion = as.numeric(Ocupacion),
      Velocidad = as.numeric(Velocidad)
    ) %>%
    select(CodigoSeccion, Intensidad, Ocupacion, Velocidad, FechaHora, geometry)
  
  # 3. Unión de ambos (API limpia + Local limpio)
  # Añadimos lo local a trafico_sf
  trafico_sf <- bind_rows(trafico_sf, trafico_local)
  
  # Opcional: Borramos trafico_local para liberar memoria
  rm(trafico_local)
  
} else {
  warning("No se encuentra el fichero local. Usando solo datos de la API.")
  # trafico_sf ya tiene la API cargada, no hay que hacer nada más
}

# Revisar nulos en el dataframe
colSums(is.na(trafico_sf))

# Revisar duplicadas en el dataframe  
sum(duplicated(trafico_sf))

# 4. Limpieza final tras la unión
# Eliminamos duplicados si se solapan fechas y renombramos para el cruce posterior
trafico_sf <- trafico_sf %>%
  distinct(CodigoSeccion, FechaHora, .keep_all = TRUE) %>%
  rename(FechaHora_trafico = FechaHora)

# Revisar  clases
class(trafico_sf)

# Mostrar primeras lineas
head(trafico_sf)

########

# [CAMBIO IMPORTANTE] Leemos el archivo local acumulado
ruta_trafico <- "traficoCSV/trafico_final.geojson"

# Leer el GeoJSON como objeto sf
trafico_sf <- st_read(ruta_trafico, quiet = TRUE)

# [LIMPIEZA Y FORMATO] Preparamos el histórico para que coincida
trafico_sf <- trafico_sf %>%
  mutate(
    # Parseamos la fecha ISO (formato 2026-02-01T18:50:00Z)
    FechaHora_trafico = ymd_hms(FechaHora),
    
    # Aseguramos que los datos numéricos sean números
    Intensidad = as.numeric(Intensidad),
    Ocupacion = as.numeric(Ocupacion),
    Velocidad = as.numeric(Velocidad)
  ) %>%
  # Eliminamos la columna fecha original para no confundirnos
  select(-FechaHora)

# Mostrar clases y primeras líneas
head(trafico_sf)


############################ UNIÓN DE MEDICIONES CON UBICACIÓN ############################

# Combinar datos por código de sonómetro
sonometros_sf <- sonometros_mediciones_df %>%
  left_join(sonometro_ubicacion_sf, by = c("Codigo" = "name")) %>%
  st_as_sf()

# Eliminar registros sin geometría válida
sonometros_sf <- sonometros_sf[!is.na(st_dimension(sonometros_sf)), ]


############################ ANÁLISIS Y LIMPIEZA DE OUTLIERS ############################
# (MOVIDO AQUÍ: Limpiamos los ruidos erróneos ANTES de cruzar con tráfico)

# Diagnóstico Visual
boxplot(sonometros_sf$Decibelios, main = "Detectando Outliers en dB (Antes de cruzar)")

# TRATAMIENTO: Filtramos valores lógicos de ciudad (30dB - 120dB)
sonometros_clean <- sonometros_sf %>%
  filter(Decibelios > 30 & Decibelios < 120)

# Ver cuántos datos se han eliminado
cat("Datos eliminados por ruido erróneo:", nrow(sonometros_sf) - nrow(sonometros_clean), "\n")


############################ UNIÓN CON TRÁFICO (NUEVA LÓGICA) ############################

# 1. Obtenemos las ubicaciones ÚNICAS de los tramos de tráfico (para saber cuál está cerca)
trafico_tramos_unicos <- trafico_sf %>% 
  distinct(CodigoSeccion, .keep_all = TRUE) %>%
  select(CodigoSeccion, geometry)

# 2. UNIÓN ESPACIAL: Buscamos qué tramo (CodigoSeccion) está más cerca de cada sonómetro
idx <- st_nearest_feature(sonometros_clean, trafico_tramos_unicos)

# Asignamos el CodigoSeccion del tráfico al sonómetro
sonometros_clean$CodigoSeccion <- trafico_tramos_unicos$CodigoSeccion[idx]

# 3. UNIÓN DE DATOS: Ahora traemos TODO el histórico de tráfico cruzando por CodigoSeccion
#    Usamos st_drop_geometry para que el join sea rápido y no duplique geometrías
sonometros_trafico_sf <- sonometros_clean %>%
  left_join(st_drop_geometry(trafico_sf), by = "CodigoSeccion", relationship = "many-to-many")

# NOTA: Ahora 'sonometros_trafico_sf' tiene MUCHAS filas, porque cada medición de ruido
# se ha unido con todo el historial de tráfico de su calle. El siguiente paso lo filtra.


##############################
# --- PASO 2: Sincronización Temporal ---

# Calcular la diferencia de tiempo absoluta en minutos
sonometros_trafico_sf <- sonometros_trafico_sf %>%
  mutate(Dif_Minutos = abs(as.numeric(difftime(FechaHora, FechaHora_trafico, units = "mins"))))

# Revisamos qué tan desfasados están los datos
summary(sonometros_trafico_sf$Dif_Minutos)

# DECISIÓN DE CALIDAD:
# Filtramos para quedarnos solo con datos donde la diferencia sea menor a 15 minutos.
sonometros_final <- sonometros_trafico_sf %>%
  filter(Dif_Minutos <= 15)

# Ver cuántos datos nos quedan tras la sincronización
cat("Registros tras cruce espacial:", nrow(sonometros_trafico_sf), "\n")
cat("Registros finales sincronizados:", nrow(sonometros_final), "\n")


# --- PASO 3: Limpieza Final de Nulos ---

# Eliminamos filas que sigan teniendo nulos en datos críticos
sonometros_final <- sonometros_final %>%
  drop_na(Ocupacion, Intensidad, Velocidad)

# Verificación final
print(dim(sonometros_final))
head(sonometros_final)