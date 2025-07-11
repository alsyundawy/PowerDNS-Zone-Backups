
#!/usr/bin/env bash
#========================================================
# DNS Zone Backup & Restore Utility for PowerDNS
# Elegant, Informative, and Easy to Maintain
#========================================================

set -euo pipefail
IFS=$'\n\t'

# -----------------------------
# Configuration
# -----------------------------
PDNSUTIL="/usr/bin/pdnsutil"
ZONE_DIR="/root/zones-backup"
RETENTION_DAYS=28
DATE_SUFFIX="$(date +%Y%m%d)"
PARALLEL_JOBS=4

# ANSI Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

# -----------------------------
# Logging Function
# -----------------------------
log() {
  local color="$1"; shift
  local ts="$(date +'%Y-%m-%d %H:%M:%S')"
  echo -e "${color}[${ts}] $*${RESET}"
}

# -----------------------------
# Ensure Backup Directory Exists
# -----------------------------
mkdir -p "${ZONE_DIR}"

# -----------------------------
# Export Zones Function
# -----------------------------
export_zones() {
  log "${CYAN}" "Starting zone export to ${ZONE_DIR} ..."
  local zones
  IFS=$'\n' read -r -d '' -a zones < <(${PDNSUTIL} list-all-zones; printf '\0')

  if [[ ${#zones[@]} -eq 0 ]]; then
    log "${YELLOW}" "No zones found."
    return
  fi

  log "${GREEN}" "Found ${#zones[@]} zones. Exporting..."
  export EXPORT_DIR="${ZONE_DIR}" PDNSUTIL

  export_zone() {
    local z="$1"
    local outfile="${EXPORT_DIR}/${z}-${DATE_SUFFIX}.zone"
    if ${PDNSUTIL} list-zone "$z" > "$outfile"; then
      log "${GREEN}" "Exported zone '$z' -> $outfile"
    else
      log "${RED}" "Failed to export zone '$z'"
    fi
  }
  export -f export_zone

  if command -v parallel &>/dev/null; then
    printf '%s\0' "${zones[@]}" | parallel -0 -j${PARALLEL_JOBS} export_zone {}
  else
    for z in "${zones[@]}"; do
      export_zone "$z"
    done
  fi

  log "${CYAN}" "Cleaning backups older than ${RETENTION_DAYS} days..."
  find "${ZONE_DIR}" -type f -name "*.zone" -mtime +${RETENTION_DAYS} -print -exec rm -f {} +
  log "${CYAN}" "Export complete."
}

# -----------------------------
# Import Zones Function
# -----------------------------
import_zones() {
  log "${CYAN}" "Starting zone import from ${ZONE_DIR} ..."

  mapfile -d '' files < <(find "${ZONE_DIR}" -maxdepth 1 -type f -name '*-[0-9]\{8\}.zone' -print0)
  if [[ ${#files[@]} -eq 0 ]]; then
    log "${YELLOW}" "No backup files found in ${ZONE_DIR}."
    return
  fi

  declare -A existing
  while read -r z; do existing["$z"]=1; done < <(${PDNSUTIL} list-all-zones)

  declare -A latest
  for f in "${files[@]}"; do
    local bn
    bn=$(basename "$f")
    local name
    name=${bn%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].zone}
    if [[ -z "${latest[$name]:-}" || "$f" -nt "${latest[$name]}" ]]; then
      latest[$name]="$f"
    fi
  done

  import_one() {
    local f="$1"
    local bn
    bn=$(basename "$f")
    local name
    name=${bn%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].zone}
    if [[ -n "${existing[$name]:-}" ]]; then
      ${PDNSUTIL} delete-zone "$name" && log "${YELLOW}" "Deleted old zone '$name'"
    fi
    if ${PDNSUTIL} load-zone "$name" "$f"; then
      log "${GREEN}" "Imported zone '$name' from $bn"
    else
      log "${RED}" "Failed to import zone '$name'"
    fi
  }
  export -f import_one

  printf '%s\0' "${latest[@]}" | xargs -0 -n1 -P${PARALLEL_JOBS} bash -c 'import_one "$0"'

  log "${CYAN}" "Import complete."
}

# -----------------------------
# Main Menu
# -----------------------------
while :; do
  echo -e "${MAGENTA}===========================================${RESET}"
  echo -e "${BLUE}  PowerDNS Zone Backup & Restore Utility${RESET}"
  echo -e "${MAGENTA}===========================================${RESET}"
  echo -e "${YELLOW}1) Export (Backup) Zones\n2) Import (Restore) Zones\n3) Exit${RESET}"
  read -rp "Select an option [1-3]: " choice
  case "$choice" in
    1) export_zones ;;  
    2) import_zones ;;  
    3) log "${MAGENTA}" "Exiting..."; exit 0 ;;  
    *) log "${RED}" "Invalid option. Try again." ;;  
  esac
  echo
  sleep 1
done

