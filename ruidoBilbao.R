# Librerías
library(jsonlite)

# Directorio de trabajo
getwd()

# Descargar y cargar JSON
url <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_mediciones.jsp?idioma=c&formato=json"

# Leer JSON desde la web
datos_json <- fromJSON(url)

# revisar nulos
colSums(is.na(datos_json)) 

# Comprobación inicial
str(datos_json)
head(datos_json)

# Crear un dataframe limpio
sonometros_df <- data.frame(
  Codigo = datos_json$nombre_dispositivo,
  Decibelios = as.numeric(datos_json$decibelios),
  FechaHora = as.POSIXct(datos_json$fecha_medicion, format="%Y-%m-%d %H:%M:%OS"),
  stringsAsFactors = FALSE
)

# Extraer información adicional
sonometros_df$Hora <- format(sonometros_df$FechaHora, "%H")   # hora del día
sonometros_df$Dia <- weekdays(sonometros_df$FechaHora)        # día de la semana

# Estadísticas básicas del ruido (Minimo| 1st cuartil| Mediana| Media|
summary(sonometros_df$Decibelios)

# La desviación estándar, que indica cuánto varían los niveles de ruido respecto a la media.
sd(sonometros_df$Decibelios)

# Visualización
# Histograma
hist(sonometros_df$Decibelios,
     main="Distribución de niveles de ruido",
     xlab="Decibelios (dB)",
     col="skyblue",
     breaks=30)

# Boxplot por sonómetro
boxplot(Decibelios ~ Codigo, data=sonometros_df,
        main="Nivel de ruido por sonómetro",
        xlab="Sonómetro",
        ylab="Decibelios (dB)",
        las=2,
        col="lightgreen")

# Resultado final
head(sonometros_df)
