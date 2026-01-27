# Mirar en que directotio estamos 
getwd()

# importar .csv
sonometros_mediciones <- read.csv("sonometros_mediciones.csv",header = TRUE,sep = ";",stringsAsFactors = FALSE)
sonometros_mediciones

# Comprobar si hay nulos
colSums(is.na(sonometros_mediciones))

# Revisar los tipos de datos
str(sonometros_mediciones)
head(sonometros_mediciones)

# Convertir la columna Fecha.Hora.medicion a datetime
sonometros_mediciones$Fecha.Hora.medicion <- as.POSIXct(
  sonometros_mediciones$Fecha.Hora.medicion,
  format = "%Y-%m-%d %H:%M:%OS"
)

# Extraer hora y día de la semana (muy útil para análisis de ruido)
# Hora del día
sonometros_mediciones$Hora <- format(sonometros_mediciones$Fecha.Hora.medicion, "%H")

# Día de la semana
sonometros_mediciones$Dia <- weekdays(sonometros_mediciones$Fecha.Hora.medicion)

# Estadísticas básicas del ruido (Minimo| 1st cuartil| Mediana| Media| 3rd cuartil| Maximo )
summary(sonometros_mediciones$Decibelios.medidos)
# La desviación estándar, que indica cuánto varían los niveles de ruido respecto a la media.
sd(sonometros_mediciones$Decibelios.medidos)

# Visualización inicial

# Histograma del ruido
hist(sonometros_mediciones$Decibelios.medidos,
     main="Distribución de niveles de ruido",
     xlab="Decibelios (dB)",
     col="skyblue",
     breaks=30)

#Boxplot por sonómetro
boxplot(Decibelios.medidos ~ Codigo, data=sonometros_mediciones,
        main="Nivel de ruido por sonómetro",
        xlab="Sonómetro",
        ylab="Decibelios (dB)",
        las=2, col="lightgreen")

