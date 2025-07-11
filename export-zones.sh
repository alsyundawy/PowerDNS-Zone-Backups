#!/usr/bin/env bash

#================================================
# export-zones.sh
# Optimized script untuk mengekspor zona PowerDNS
#================================================

set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------
# Konfigurasi
# -----------------------------------------------
EXPORT_DIR="/root/zones-backup"
PDNSUTIL="/usr/bin/pdnsutil"
RETENTION_DAYS=28
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

# Periksa apakah daftar zona kosong
mapfile -t zones <<< "${zones_raw}"
if [[ ${#zones[@]} -eq 0 ]]; then
    log "Tidak ada zona yang ditemukan."
    exit 0
fi
log "Ditemukan ${#zones[@]} zona."

# -----------------------------------------------
# Ekspor zona satu per satu (paralel jika tersedia)
# -----------------------------------------------
export_zone() {
    local z="$1"
    local outfile="${EXPORT_DIR}/${z}-${DATE_SUFFIX}.zone"

    if ${PDNSUTIL} list-zone "${z}" > "${outfile}"; then
        log "Zona '${z}' diekspor -> ${outfile}"
    else
        log "ERROR: Gagal mengekspor zona '${z}'"
        return 1
    fi
}
export -f export_zone
export EXPORT_DIR PDNSUTIL DATE_SUFFIX

# Cek apakah GNU parallel terpasang
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
