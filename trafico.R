# Librerías
library(sf)

# Directorio de trabajo
getwd()

# URL del GeoJSON de tráfico
url_trafico <- "https://www.bilbao.eus/aytoonline/srvDatasetTrafico?formato=geojson"

# Leer el GeoJSON como objeto sf (dataframe con geometría)
trafico_sf <- sf::st_read(url_trafico)

# Revisar nulos en el dataframe
colSums(is.na(trafico_sf))

# Eliminar filas donde Decibelios es NA
trafico_sf <- trafico_sf[!is.na(trafico_sf$Decibelios), ]

# Revisar duplicadas en el dataframe  
sum(duplicated(trafico_sf))

# Eliminar filas donde Decibelios es duplicado
trafico_sf <- trafico_sf[!duplicated(trafico_sf), ]


