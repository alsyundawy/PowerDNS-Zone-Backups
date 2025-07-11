#!/bin/bash

# Direktori tempat file zona disimpan
IMPORT_DIR="/root/zones-backup"

# Mendapatkan daftar file zona yang akan diimpor
zone_files=$(find "$IMPORT_DIR" -type f -name '*.zone')

# Memeriksa apakah ada file zona yang ditemukan
if [ -z "$zone_files" ]; then
    echo "Tidak ada file zona yang ditemukan untuk diimpor."
    exit 1
fi

# Mengimpor setiap file zona
for zone_file in $zone_files; do
    # Mendapatkan nama zona dari nama file
    zone=$(basename "$zone_file" | sed -e 's/-[0-9]\{8\}\.zone$//')
    
    # Memeriksa apakah zona sudah ada di PowerDNS
    if pdnsutil list-all-zones | grep -q "$zone"; then
        # Jika zona sudah ada, hapus zona lama
        pdnsutil delete-zone "$zone"
    fi
    
    # Mengimpor zona baru dari file
    pdnsutil load-zone "$zone" "$zone_file"
    
    if [ $? -eq 0 ]; then
        echo "Zona $zone berhasil diimpor dari $zone_file"
    else
        echo "Gagal mengimpor zona $zone dari $zone_file"
    fi
done

echo "Proses impor selesai."
