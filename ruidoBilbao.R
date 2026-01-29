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


####################################################### SONÓMETRO: MEDICIONES #######################################################


# URL del GeoJSON de sonometro_mediciones
url_sonometro_mediciones <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_mediciones.jsp?idioma=c&formato=json"

# Leer JSON desde la web
sonometros_mediciones_df <- fromJSON(url_sonometro_mediciones)

# Crear el dataframe de Sonometro_mediciones
sonometros_mediciones_df <- data.frame(
  Codigo = sonometros_mediciones_df$nombre_dispositivo,
  Decibelios = as.numeric(sonometros_mediciones_df$decibelios),
  FechaHora = as.POSIXct(sonometros_mediciones_df$fecha_medicion, format="%Y-%m-%d %H:%M:%OS"),
  stringsAsFactors = FALSE
)

# Revisar nulos en el dataframe
colSums(is.na(sonometros_mediciones_df))

# Revisar duplicadas en el dataframe  
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


####################################################### SONÓMETRO: UBICACIÓN #######################################################


# URL del GeoJSON de sonometro_ubicacion
url_sonometro_ubicacion <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_ubicacion.jsp?idioma=c&formato=geojson"

# Leer el GeoJSON como objeto sf (dataframe con geometría)
sonometro_ubicacion_sf <- sf::st_read(url_sonometro_ubicacion)

# Revisar nulos en el dataframe
colSums(is.na(sonometro_ubicacion_sf))

# Revisar duplicadas en el dataframe  
sum(duplicated(sonometro_ubicacion_sf))

# Revisar  clases
class(sonometro_ubicacion_sf)

# Mostrar primeras lineas
head(sonometro_ubicacion_sf)


####################################################### TRÁFICO #######################################################


# URL del GeoJSON de tráfico
url_trafico <- "https://www.bilbao.eus/aytoonline/srvDatasetTrafico?formato=geojson"

# Leer el GeoJSON como objeto sf (dataframe con geometría)
trafico_sf <- sf::st_read(url_trafico)

# Revisar nulos en el dataframe
colSums(is.na(trafico_sf))

# Revisar duplicadas en el dataframe  
sum(duplicated(trafico_sf))

# Revisar  clases
class(trafico_sf)

# Mostrar primeras lineas
head(trafico_sf)


#######################################################  UNIÓN DE MEDICIONES CON UBICACIÓN ####################################################### 


# Combinar datos por código de sonómetro
sonometros_sf <- sonometros_mediciones_df %>%
  left_join(sonometro_ubicacion_sf, by = c("Codigo" = "name")) %>%
  st_as_sf()

# Revisar clases
class(sonometros_sf)

# Mostrar primeras lineas
head(sonometros_sf)


#######################################################  UNIÓN DE MEDICIONES CON TRÁFICO ####################################################### 


# UNIÓN ESPACIAL CON TRÁFICO
# Cada punto de sonómetro se asocia con el polígono de tráfico donde cae
# st_join usa la geometría de los objetos
idx <- st_nearest_feature(sonometros_sf, trafico_sf)

sonometros_trafico_sf <- sonometros_sf %>%
  mutate(
    CodigoSeccion = trafico_sf$CodigoSeccion[idx],
    Ocupacion     = trafico_sf$Ocupacion[idx],
    Intensidad    = trafico_sf$Intensidad[idx],
    Velocidad     = trafico_sf$Velocidad[idx],
    FechaHora_trafico = trafico_sf$FechaHora[idx]
  )


# Revisar resultado
class(sonometros_trafico_sf)

# Mostrar primeras lineas
head(sonometros_trafico_sf)
