import json
import os
import glob

archivo_salida = 'trafico_final.geojson'
archivos_entrada = glob.glob('*.geojson')

geojson_unido = {
    "type": "FeatureCollection",
    "features": []
}

print(f"Procesando {len(archivos_entrada)} archivos...")

for nombre_archivo in archivos_entrada:
    # Evitamos leernos a nosotros mismos si el archivo de salida ya existe
    if nombre_archivo == archivo_salida: 
        continue

    features_archivo = []
    try:
        with open(nombre_archivo, 'r', encoding='utf-8') as f:
            content = f.read() # Leemos todo el contenido de golpe
            
            # INTENTO 1: Carga normal (para archivos estándar como 27-01 y 29-01)
            try:
                data = json.loads(content)
                if isinstance(data, dict) and data.get('type') == 'FeatureCollection':
                    features_archivo.extend(data.get('features', []))
                elif isinstance(data, dict) and data.get('type') == 'Feature':
                    features_archivo.append(data)
                
            except json.JSONDecodeError:
                # INTENTO 2: Decodificación secuencial (para 01-02 con "Extra Data")
                print(f"   -> Detectado formato complejo en {nombre_archivo}. Usando decodificador avanzado...")
                
                decoder = json.JSONDecoder()
                pos = 0
                longitud = len(content)
                
                while pos < longitud:
                    # Saltamos espacios en blanco o saltos de línea
                    while pos < longitud and content[pos].isspace():
                        pos += 1
                    if pos >= longitud:
                        break
                    
                    try:
                        # raw_decode lee UN objeto JSON válido y nos dice dónde termina
                        obj, end_pos = decoder.raw_decode(content, idx=pos)
                        pos = end_pos # Avanzamos el cursor al final de ese objeto
                        
                        if isinstance(obj, dict):
                            if obj.get('type') == 'Feature':
                                features_archivo.append(obj)
                            elif obj.get('type') == 'FeatureCollection':
                                features_archivo.extend(obj.get('features', []))
                                
                    except json.JSONDecodeError:
                        # Si falla en un punto, intentamos avanzar un caracter para no bloquearnos
                        pos += 1

        if features_archivo:
            geojson_unido['features'].extend(features_archivo)
            print(f"   -> {nombre_archivo}: ¡Éxito! Se recuperaron {len(features_archivo)} entidades.")
        else:
            print(f"   -> {nombre_archivo}: No se encontraron datos válidos.")

    except Exception as e:
        print(f"Error crítico leyendo {nombre_archivo}: {e}")

# Guardar el resultado final
try:
    with open(archivo_salida, 'w', encoding='utf-8') as f_out:
        json.dump(geojson_unido, f_out, indent=2)
    print(f"\n¡Operación completada! Archivo guardado como: {archivo_salida}")
    print(f"Total de entidades recolectadas: {len(geojson_unido['features'])}")
except Exception as e:
    print(f"Error guardando el archivo: {e}")