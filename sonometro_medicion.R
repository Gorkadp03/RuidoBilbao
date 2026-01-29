# CARGA DE LIBRERÍAS Y DATOS
library(jsonlite)

# Directorio de trabajo
getwd()

# Sonometro_mediciones

# Descargar y cargar JSON
url_sonometro_mediciones <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_mediciones.jsp?idioma=c&formato=json"

# Leer JSON desde la web
sonometros_mediciones_json <- fromJSON(url_sonometro_mediciones)

# Crear el dataframe de Sonometro_mediciones
sonometros_mediciones_df <- data.frame(
  Codigo = sonometros_mediciones_json$nombre_dispositivo,
  Decibelios = as.numeric(sonometros_mediciones_json$decibelios),
  FechaHora = as.POSIXct(sonometros_mediciones_json$fecha_medicion, format="%Y-%m-%d %H:%M:%OS"),
  stringsAsFactors = FALSE
)

# Revisar nulos en el dataframe
colSums(is.na(sonometros_mediciones_df))

# Eliminar filas donde Decibelios es NA
sonometros_mediciones_df <- sonometros_mediciones_df[!is.na(sonometros_mediciones_df$Decibelios), ]

# Revisar duplicadas en el dataframe  
sum(duplicated(sonometros_mediciones_df))

# Eliminar filas donde Decibelios es duplicado
sonometros_mediciones_df <- sonometros_mediciones_df[!duplicated(sonometros_mediciones_df), ]

# Extraer información adicional (Hora y Día)
sonometros_mediciones_df$Hora <- format(sonometros_mediciones_df$FechaHora, "%H")
sonometros_mediciones_df$Dia <- weekdays(sonometros_mediciones_df$FechaHora)

# Mostrar las primeras lineas
head(sonometros_mediciones_df)

# Mostrar ( Mínimo, Primer cuartil, Mediana, Promedio, Tercer cuartil, Máximo )
summary(sonometros_mediciones_df$Decibelios)

# Mostrar la desviación Estándar
print(sd(sonometros_mediciones_df$Decibelios))

# Visualización
# Histograma
hist(sonometros_mediciones_df$Decibelios,
     main="Distribución de niveles de ruido",
     xlab="Decibelios (dB)",
     col="skyblue",
     breaks=30)


# Boxplot por sonómetro
boxplot(Decibelios ~ Codigo, data=sonometros_mediciones_df,
        main="Nivel de ruido por sonómetro",
        xlab="Sonómetro",
        ylab="Decibelios (dB)",
        las=2,
        col="lightgreen")
