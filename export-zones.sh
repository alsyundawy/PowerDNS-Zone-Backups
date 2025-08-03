#!/usr/bin/env bash

#================================================
# export-zones.sh
# Optimized script untuk mengekspor zona PowerDNS dengan
# dukungan handling both reverse-zone (IPv4 & IPv6) and forward zones,
# menampilkan PTR relatif tanpa duplikasi $ORIGIN . dan A/AAAA relatif
# tanpa domain suffix dan TTL.
#================================================

set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------
# Konfigurasi
# -----------------------------------------------
EXPORT_DIR="/root/zones-backup"
PDNSUTIL="/usr/bin/pdnsutil"
RETENTION_DAYS=14
DATE_SUFFIX="$(date +%Y%m%d)"

# -----------------------------------------------
# Fungsi: Logging
# -----------------------------------------------
log() {
    local ts
    ts="$(date +'%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*"
}

# -----------------------------------------------
# Pastikan direktori backup ada
# -----------------------------------------------
mkdir -p "${EXPORT_DIR}"
log "Backup directory: ${EXPORT_DIR}"

# -----------------------------------------------
# Ambil daftar zona
# -----------------------------------------------
log "Mengambil daftar zona dari PowerDNS..."
if ! zones_raw="$(${PDNSUTIL} list-all-zones)"; then
    log "ERROR: Gagal menjalankan pdnsutil."
    exit 1
fi
mapfile -t zones <<< "${zones_raw}"
if [[ ${#zones[@]} -eq 0 ]]; then
    log "Tidak ada zona yang ditemukan."
    exit 0
fi
log "Ditemukan ${#zones[@]} zona."

# -----------------------------------------------
# Fungsi: Ekspor satu zona
# -----------------------------------------------
export_zone() {
    local z="$1"
    local outfile="${EXPORT_DIR}/${z}-${DATE_SUFFIX}.zone"

    if ${PDNSUTIL} list-zone "${z}" > "${outfile}"; then
        log "Zona '${z}' diekspor -> ${outfile}"

        if [[ "${z}" =~ \.in-addr\.arpa$ ]] || [[ "${z}" =~ \.ip6\.arpa$ ]]; then
            # Reverse zones
            log "Memproses reverse-zone ${z}"
            sed -i '/^\$ORIGIN \.$/d' "${outfile}"
            sed -i '1i\$ORIGIN .\n' "${outfile}"
            sed -i -E "s#^${z}[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+NS[[:space:]]+(.+)#@\tIN\tNS\t\1#" "${outfile}"
            sed -i -E "s#^${z}[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+SOA[[:space:]]+(.+)#@\tIN\tSOA\t\1#" "${outfile}"
            sed -i -E "s#^([0-9A-Fa-f\.]+)\.${z}[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+PTR[[:space:]]+(.+)#\1\tIN\tPTR\t\2#" "${outfile}"
        else
            # Forward zones
            log "Memproses forward-zone ${z}"
            # Strip domain suffix and TTL for A, AAAA, CNAME, etc.
            sed -i -E "s#^([^\.]+)\.${z}[[:space:]]+[0-9]+[[:space:]]+IN[[:space:]]+([A-Z]+)[[:space:]]+(.+)#\1\tIN\t\2\t\3#" "${outfile}"
        fi
    else
        log "ERROR: Gagal mengekspor zona '${z}'"
        return 1
    fi
}
export -f export_zone
export EXPORT_DIR PDNSUTIL DATE_SUFFIX

# -----------------------------------------------
# Eksekusi ekspor (paralel jika tersedia)
# -----------------------------------------------
if command -v parallel &>/dev/null; then
    log "Menjalankan ekspor zona secara paralel..."
    printf "%s\n" "${zones[@]}" | parallel -j0 export_zone {}
else
    log "Menjalankan ekspor zona secara serial..."
    for z in "${zones[@]}"; do
        export_zone "${z}"
    done
fi

# -----------------------------------------------
# Hapus backup lama
# -----------------------------------------------
log "Menghapus file backup lebih dari ${RETENTION_DAYS} hari..."
find "${EXPORT_DIR}" -type f -name "*.zone" -mtime +${RETENTION_DAYS} -print -exec rm -f {} +

log "Proses ekspor selesai."
