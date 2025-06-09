#!/bin/bash
# Script para generar blackdomains.txt localmente
# Uso: ./generar_blacklist.sh [--latam] [--pais PAIS]

# Configuración
OUTPUT_FILE="blackdomains.txt"
TEMP_FILE=$(mktemp)
LOG_FILE="blacklist_log.txt"

# Inicializar archivos
echo "=== Inicio de generación: $(date) ===" > "$LOG_FILE"
> "$OUTPUT_FILE"

## 1. Listas Globales (siempre se incluyen)
echo "Descargando listas globales..." >> "$LOG_FILE"

# Spamhaus DBL (Dominios de spam)
echo " - Spamhaus DBL" >> "$LOG_FILE"
curl -s "https://www.spamhaus.org/drop/dbl.txt" 2>> "$LOG_FILE" | \
  grep -v '^;' | awk '{print $1}' >> "$TEMP_FILE"

# URLhaus (Malware activo)
echo " - URLhaus" >> "$LOG_FILE"
curl -s "https://urlhaus.abuse.ch/downloads/text_online/" 2>> "$LOG_FILE" | \
  grep -E '^http[s]?://' | awk -F/ '{print $3}' >> "$TEMP_FILE"

## 2. Listas Latinoamericanas (opcional con --latam)
if [[ "$*" == *"--latam"* ]]; then
    echo "Descargando listas LATAM..." >> "$LOG_FILE"
    
    # CERT.AR (Argentina)
    echo " - CERT.AR" >> "$LOG_FILE"
    curl -s "https://www.cert.ar/feed/phishing-domains.txt" 2>> "$LOG_FILE" >> "$TEMP_FILE"
    
    # Dominios LATAM (extensiones regionales)
    echo " - Filtro LATAM" >> "$LOG_FILE"
    curl -s "https://urlhaus.abuse.ch/downloads/text_online/" 2>> "$LOG_FILE" | \
      grep -E '\.(ar|br|cl|co|mx|pe|uy|py|cr|do|gt)$' | \
      awk -F/ '{print $3}' >> "$TEMP_FILE"
fi

## 3. Listas por País (opcional con --pais)
if [[ "$*" == *"--pais"* ]]; then
    country=$(echo "$*" | grep -oP '(?<=--pais )\w+')
    echo "Descargando listas para $country..." >> "$LOG_FILE"
    
    case $country in
        argentina|ar)
            # Lista adicional para Argentina
            curl -s "https://lista.negra.argentina.local/dominios.txt" 2>> "$LOG_FILE" >> "$TEMP_FILE"
            ;;
        brasil|br)
            # CERT.br
            curl -s "https://www.cert.br/docs/blacklist.txt" 2>> "$LOG_FILE" >> "$TEMP_FILE"
            ;;
        chile|cl)
            # CSIRT Chile
            curl -s "https://www.csirt.gob.cl/alertas/dominios-maliciosos.txt" 2>> "$LOG_FILE" >> "$TEMP_FILE"
            ;;
        mexico|mx)
            # CERT-MX
            curl -s "https://www.cert-mx.org/malicious-domains.txt" 2>> "$LOG_FILE" >> "$TEMP_FILE"
            ;;
        *)
            echo "País no reconocido: $country" >> "$LOG_FILE"
            ;;
    esac
fi

## Procesamiento final
echo "Procesando lista final..." >> "$LOG_FILE"

# Ordenar y eliminar duplicados
sort -u "$TEMP_FILE" > "$OUTPUT_FILE"

# Estadísticas finales
LINES_TOTAL=$(wc -l < "$OUTPUT_FILE")
echo "=== Generación completada ===" >> "$LOG_FILE"
echo "Dominios en lista: $LINES_TOTAL" >> "$LOG_FILE"
echo "Archivo generado: $OUTPUT_FILE" >> "$LOG_FILE"

# Limpieza
rm "$TEMP_FILE"

echo "¡Listo! Archivo $OUTPUT_FILE generado correctamente."
echo "Detalles del proceso en $LOG_FILE"
