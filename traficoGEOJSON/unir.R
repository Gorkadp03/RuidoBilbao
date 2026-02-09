library(sf)
library(dplyr)

# 1. Definir el directorio de trabajo
# Si el script está en la misma carpeta que los archivos, usa getwd().
# Si no, cambia la ruta aquí, ejemplo: setwd("C:/MisDocumentos/DatosTrafico")
directorio <- getwd()

# 2. Listar todos los archivos .geojson
# full.names = TRUE es importante para que R encuentre la ruta completa
archivos <- list.files(path = directorio, 
                       pattern = "\\.geojson$", 
                       full.names = TRUE, 
                       ignore.case = TRUE)

# 3. Definir el nombre del archivo de salida
archivo_salida <- file.path(directorio, "trafico_final.geojson")

# 4. Filtrar: Evitar leer el archivo de salida si ya existe de una ejecución anterior
# Esto previene que el archivo final se duplique a sí mismo infinitamente
archivos <- archivos[archivos != archivo_salida]

# Verificar si hay archivos para procesar
if (length(archivos) == 0) {
  stop("No se encontraron archivos .geojson en la carpeta.")
}

message(paste("Se han encontrado", length(archivos), "archivos para unir."))

# 5. Leer y unir los archivos
# Usamos lapply para leerlos en una lista y luego bind_rows para unirlos
tryCatch({
  
  lista_geo <- lapply(archivos, function(x) {
    st_read(x, quiet = TRUE) # quiet=TRUE reduce el ruido en la consola
  })
  
  # Unimos todos los sf objects en uno solo
  # bind_rows es útil porque si un archivo tiene una columna que otro no, pone NA en lugar de error
  trafico_combinado <- bind_rows(lista_geo)
  
  # 6. Guardar el resultado
  # delete_dsn = TRUE permite sobrescribir el archivo si ya existe
  st_write(trafico_combinado, archivo_salida, delete_dsn = TRUE)
  
  message("¡Éxito! Archivo guardado en: ", archivo_salida)
  
}, error = function(e) {
  message("Ocurrió un error al procesar los archivos:")
  message(e)
})

