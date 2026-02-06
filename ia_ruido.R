# CARGA DE LIBRERÍAS
library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(sf)
library(ggplot2)

# ESTABLECER DIRECTORIO DE TRABAJO (Tu ruta específica)
print(paste("Directorio de trabajo actual:", getwd()))

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
print("Revisión de nulos en mediciones:")
print(colSums(is.na(sonometros_mediciones_df)))
print(paste("Duplicados en mediciones:", sum(duplicated(sonometros_mediciones_df))))

# Extraer información adicional (Hora y Día)
sonometros_mediciones_df$Hora <- format(sonometros_mediciones_df$FechaHora, "%H")
# Usamos wday para asegurar compatibilidad de idioma
sonometros_mediciones_df$DiaSemana <- weekdays(sonometros_mediciones_df$FechaHora)
sonometros_mediciones_df$TipoDia <- ifelse(
  weekdays(sonometros_mediciones_df$FechaHora) %in% c("sábado", "domingo", "Saturday", "Sunday"), 
  "Fin de Semana", 
  "Laborable"
)

# Mostrar estadísticas descriptivas
summary(sonometros_mediciones_df$Decibelios)


############################ SONÓMETRO: UBICACIÓN ############################

# URL del GeoJSON de sonometro_ubicacion
url_sonometro_ubicacion <- "https://www.bilbao.eus/aytoonline/jsp/opendata/movilidad/od_sonometro_ubicacion.jsp?idioma=c&formato=geojson"

# Leer el GeoJSON como objeto sf
sonometro_ubicacion_sf <- st_read(url_sonometro_ubicacion, quiet = TRUE)

# Revisar nulos
print("Revisión de nulos en ubicación:")
print(colSums(is.na(sonometro_ubicacion_sf)))


############################ TRÁFICO (API + LOCAL) ############################

# --- 1. CARGA DESDE LA API (Datos actuales) ---
url_trafico <- "https://www.bilbao.eus/aytoonline/srvDatasetTrafico?formato=geojson"
trafico_api <- st_read(url_trafico, quiet = TRUE)

# Normalizamos la API
trafico_api <- trafico_api %>%
  mutate(
    FechaHora = ymd_hms(FechaHora), # Convierte string a fecha
    Intensidad = as.numeric(Intensidad),
    Ocupacion = as.numeric(Ocupacion),
    Velocidad = as.numeric(Velocidad)
  ) %>%
  select(CodigoSeccion, Intensidad, Ocupacion, Velocidad, FechaHora, geometry)

# --- 2. CARGA DESDE TU FICHERO LOCAL (Datos históricos) ---
# Usamos la ruta ABSOLUTA que me has dado para asegurar que lo encuentre
ruta_trafico_local <- "C:/Users/iabd/Desktop/RuidoBilbao/traficoCSV/trafico_final.geojson"

if(file.exists(ruta_trafico_local)) {
  trafico_local <- st_read(ruta_trafico_local, quiet = TRUE)
  
  # Normalizamos el Local (para que coincida con la API)
  trafico_local <- trafico_local %>%
    mutate(
      FechaHora = ymd_hms(FechaHora), 
      Intensidad = as.numeric(Intensidad),
      Ocupacion = as.numeric(Ocupacion),
      Velocidad = as.numeric(Velocidad)
    ) %>%
    select(CodigoSeccion, Intensidad, Ocupacion, Velocidad, FechaHora, geometry)
  
  # --- 3. UNIÓN DE AMBOS (BIND ROWS) ---
  trafico_sf <- bind_rows(trafico_api, trafico_local)
  
} else {
  warning("Archivo local no encontrado en la ruta especificada. Se usarán solo datos de API.")
  trafico_sf <- trafico_api
}

# Limpieza final: eliminamos duplicados exactos si los hubiera y renombramos fecha
trafico_sf <- trafico_sf %>%
  distinct(CodigoSeccion, FechaHora, .keep_all = TRUE) %>%
  rename(FechaHora_trafico = FechaHora)

# Verificación
cat("Total de registros de tráfico combinados:", nrow(trafico_sf), "\n")


############################ UNIÓN DE MEDICIONES CON UBICACIÓN ############################

# Combinar datos por código de sonómetro
sonometros_sf <- sonometros_mediciones_df %>%
  left_join(sonometro_ubicacion_sf, by = c("Codigo" = "name")) %>%
  st_as_sf()

# LIMPIEZA: Eliminar registros sin geometría válida
sonometros_sf <- sonometros_sf[!is.na(st_dimension(sonometros_sf)), ]


############################ LIMPIEZA DE OUTLIERS (dB) ############################

# Diagnóstico Visual
boxplot(sonometros_sf$Decibelios, main = "Detectando Outliers en dB")

# Filtramos valores lógicos (30dB - 120dB)
sonometros_clean <- sonometros_sf %>%
  filter(Decibelios > 30 & Decibelios < 120)

cat("Datos eliminados por ruido:", nrow(sonometros_sf) - nrow(sonometros_clean), "\n")


############################ UNIÓN DE MEDICIONES CON TRÁFICO ############################

# ESTRATEGIA: 
# 1. Buscar el tramo geográfico más cercano.
# 2. Sincronización temporal optimizada (join_by).

# Paso A: Obtener geometrías únicas de los tramos de tráfico
trafico_tramos_unicos <- trafico_sf %>% 
  distinct(CodigoSeccion, .keep_all = TRUE) %>%
  select(CodigoSeccion, geometry)

# Paso B: Encontrar el índice del tramo más cercano
idx <- st_nearest_feature(sonometros_clean, trafico_tramos_unicos)

# Asignamos el ID del tramo de tráfico al sonómetro
sonometros_clean$CodigoSeccion <- trafico_tramos_unicos$CodigoSeccion[idx]

# Paso C: Unir historial de tráfico OPTIMIZADO
# Usamos join_by con closest para evitar saturación de memoria
sonometros_trafico_sf <- sonometros_clean %>%
  left_join(
    st_drop_geometry(trafico_sf), 
    by = join_by(
      CodigoSeccion == CodigoSeccion, 
      closest(FechaHora >= FechaHora_trafico) # Busca fecha tráfico más cercana (anterior)
    )
  )

##############################
# --- PASO 2: Sincronización Temporal y Filtrado ---

# Calcular la diferencia de tiempo en minutos
sonometros_final <- sonometros_trafico_sf %>%
  mutate(Dif_Minutos = abs(as.numeric(difftime(FechaHora, FechaHora_trafico, units = "mins")))) %>%
  # DECISIÓN DE CALIDAD: Filtrar diferencia <= 15 minutos
  filter(Dif_Minutos <= 15)

# Ver cuántos datos nos quedan
cat("Registros sincronizados finales:", nrow(sonometros_final), "\n")


# --- PASO 3: Limpieza Final de Nulos ---

# Eliminamos filas con nulos en datos de tráfico
sonometros_final <- sonometros_final %>%
  drop_na(Ocupacion, Intensidad, Velocidad)

# Verificación final
dim(sonometros_final)
head(sonometros_final)

# Guardar dataset final
write.csv(sonometros_final %>% st_drop_geometry(), "dataset_final_ruido_trafico.csv", row.names = FALSE)


############################ ANÁLISIS EXPLORATORIO ############################
# Extracción de conocimiento (RA1)

# 1. Caracterización por ZONAS / SONÓMETROS
analisis_zonas <- sonometros_final %>%
  group_by(Codigo) %>%
  summarise(Media_dB = mean(Decibelios), .groups = 'drop') %>%
  arrange(desc(Media_dB))

print("Zonas más ruidosas:")
print(head(analisis_zonas))

ggplot(analisis_zonas, aes(x = reorder(Codigo, Media_dB), y = Media_dB)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(title = "Nivel Medio de Ruido por Sonómetro", x = "Ubicación", y = "dB")

# 2. Caracterización por FRANJAS HORARIAS
analisis_horas <- sonometros_final %>%
  group_by(Hora) %>%
  summarise(Media_dB = mean(Decibelios), Trafico = mean(Intensidad), .groups = 'drop')

ggplot(analisis_horas, aes(x = as.numeric(Hora))) +
  geom_line(aes(y = Media_dB), color = "red", size = 1) +
  labs(title = "Perfil Horario del Ruido", x = "Hora del día", y = "dB")

# 3. Caracterización por DÍAS (Laboral vs Fin de Semana)
ggplot(sonometros_final, aes(x = TipoDia, y = Decibelios, fill = TipoDia)) +
  geom_boxplot() +
  labs(title = "Distribución de Ruido: Laboral vs Fin de Semana")

# 4. COMPORTAMIENTO DIFERENCIAL
# Relación Ruido - Tráfico
ggplot(sonometros_final, aes(x = Intensidad, y = Decibelios)) +
  geom_point(alpha = 0.1) +
  geom_smooth(method = "lm", color = "blue") +
  labs(title = "Relación Intensidad Tráfico vs Ruido", x = "Intensidad", y = "dB")

