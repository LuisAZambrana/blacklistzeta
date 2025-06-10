#!/bin/bash
# Blacklist Generator con FireHOL + Fuentes Premium
# Incluye: FireHOL, Spamhaus, Cloudflare Radar, Abuse.ch, SURBL

# Configuración
OUTPUT_FILE="blackdomains_pro.txt"
TEMP_FILE=$(mktemp)
LOG_FILE="blacklist_firehol.log"
CLOUDFLARE_API_KEY="TU_API_KEY_CLOUDFLARE"  # Opcional pero sin esto tarda mas

# Inicialización
echo "=== Generación iniciada: $(date) ===" > "$LOG_FILE"
> "$OUTPUT_FILE"

## 1. FireHOL (Listas destacadas)
echo "[+] Descargando FireHOL IPLists..." >> "$LOG_FILE"
firehol_lists=(
    "https://iplists.firehol.org/files/firehol_level1.netset"  # Anonymizers
    "https://iplists.firehol.org/files/firehol_level3.netset"  # Abusers
    "https://iplists.firehol.org/files/firehol_webclient.netset" # Malicious web clients
)

for list in "${firehol_lists[@]}"; do
    echo " - Procesando $list..." >> "$LOG_FILE"
    curl -s "$list" 2>> "$LOG_FILE" | \
        grep -E '^[0-9]' | awk '{print $1}' >> "$TEMP_FILE"
done

## 2. Spamhaus DBL (Dominios)
echo "[+] Descargando Spamhaus DBL..." >> "$LOG_FILE"
curl -s "https://www.spamhaus.org/drop/dbl.txt" 2>> "$LOG_FILE" | \
    grep -v '^;' | awk '{print $1}' >> "$TEMP_FILE"

## 3. Abuse.ch URLhaus (Malware)
echo "[+] Descargando URLhaus..." >> "$LOG_FILE"
curl -s "https://urlhaus.abuse.ch/downloads/text_online/" 2>> "$LOG_FILE" | \
    grep -E '^http[s]?://' | awk -F/ '{print $3}' >> "$TEMP_FILE"

## 4. SURBL (Dominios maliciosos)
echo "[+] Descargando SURBL..." >> "$LOG_FILE"
curl -s "http://www.surbl.org/static/lists/surbl.txt" 2>> "$LOG_FILE" >> "$TEMP_FILE"

## 5. Cloudflare Radar (Opcional - requiere API)
if [ -n "$CLOUDFLARE_API_KEY" ]; then
    echo "[+] Consultando Cloudflare Radar..." >> "$LOG_FILE"
    curl -s -X GET \
        "https://api.cloudflare.com/client/v4/radar/ranking/top/domains/malicious?limit=100" \
        -H "Authorization: Bearer $CLOUDFLARE_API_KEY" 2>> "$LOG_FILE" | \
        jq -r '.data.domains[].domain' >> "$TEMP_FILE"
fi

## Procesamiento avanzado
echo "[+] Filtrando y ordenando..." >> "$LOG_FILE"

# 1. Eliminar IPs (solo mantener dominios) - Sino queres que las elimines comenta!
grep -E '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$' "$TEMP_FILE" > "${TEMP_FILE}_filtered"

# 2. Ordenar y eliminar duplicados
sort -u "${TEMP_FILE}_filtered" > "$OUTPUT_FILE"

# 3. Eliminar subdominios no útiles (opcional) - Sino queres que las elimines comenta!
sed -i '/^[^.]*\.[^.]*$/!d' "$OUTPUT_FILE"  # Solo mantener dominio+TLD

# Estadísticas
LINES_TOTAL=$(wc -l < "$OUTPUT_FILE")
echo "[+] Dominios en lista final: $LINES_TOTAL" >> "$LOG_FILE"
echo "=== Generación completada: $(date) ===" >> "$LOG_FILE"

# Limpieza
rm "$TEMP_FILE" "${TEMP_FILE}_filtered"

echo "¡Listo! Blacklist generada en: $OUTPUT_FILE"
echo "Log completo en: $LOG_FILE"
