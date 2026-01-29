# Librerías
library(sf)

# Directorio de trabajo
getwd()

# URL del GeoJSON de sonometro_ubicacion
url_sonometro_ubicacion <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_ubicacion.jsp?idioma=c&formato=geojson"

# Leer el GeoJSON como objeto sf (dataframe con geometría)
sonometro_ubicacion_sf <- sf::st_read(url_sonometro_ubicacion)

# Revisar nulos en el dataframe
colSums(is.na(sonometro_ubicacion_sf))

# Eliminar filas donde Decibelios es NA
sonometro_ubicacion_sf <- sonometro_ubicacion_sf[!is.na(sonometro_ubicacion_sf$Decibelios), ]

# Revisar duplicadas en el dataframe  
sum(duplicated(sonometro_ubicacion_sf))

# Eliminar filas donde Decibelios es duplicado
sonometro_ubicacion_sf <- sonometro_ubicacion_sf[!duplicated(sonometro_ubicacion_sf), ]


