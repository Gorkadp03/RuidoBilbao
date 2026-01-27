# ==============================
# Librerías
# ==============================
library(jsonlite)

# ==============================
# Directorio de trabajo
# ==============================
getwd()

# ==============================
# Descargar y cargar JSON
# ==============================
url <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_mediciones.jsp?idioma=c&formato=json"

# Leer JSON desde la web
sonometros_mediciones <- fromJSON(url)

# ==============================
# Comprobación inicial
# ==============================
# Ver nulos
colSums(is.na(sonometros_mediciones))

# Revisar tipos de datos
str(sonometros_mediciones)
head(sonometros_mediciones)

# ==============================
# Limpieza y transformación
# ==============================
# Convertir decibelios a numérico
sonometros_mediciones$decibelios <- as.numeric(sonometros_mediciones$decibelios)

# Convertir fecha a datetime
sonometros_mediciones$fecha_medicion <- as.POSIXct(
  sonometros_mediciones$fecha_medicion,
  format = "%Y-%m-%d %H:%M:%OS"
)

# Extraer hora y día de la semana
sonometros_mediciones$Hora <- format(sonometros_mediciones$fecha_medicion, "%H")
sonometros_mediciones$Dia <- weekdays(sonometros_mediciones$fecha_medicion)

# ==============================
# Estadísticas básicas del ruido
# ==============================
summary(sonometros_mediciones$decibelios)
sd(sonometros_mediciones$decibelios)

# ==============================
# Visualización inicial
# ==============================
# Histograma del ruido
hist(sonometros_mediciones$decibelios,
     main="Distribución de niveles de ruido",
     xlab="Decibelios (dB)",
     col="skyblue",
     breaks=30)

# Boxplot por sonómetro
boxplot(decibelios ~ nombre_dispositivo, data=sonometros_mediciones,
        main="Nivel de ruido por sonómetro",
        xlab="Sonómetro",
        ylab="Decibelios (dB)",
        las=2, col="lightgreen")

# ==============================
# Resultado final
# ==============================
sonometros_mediciones
