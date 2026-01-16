#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Usage:
#   ./vcf_json_table.sh <VCF_DIR> <JSON_DIR>
# Example:
#   ./vcf_json_table.sh /path/to/vcfs /path/to/jsons
VCF_DIR="${1:?Usage: $0 <VCF_DIR> <JSON_DIR>}"
JSON_DIR="${2:?Usage: $0 <VCF_DIR> <JSON_DIR>}"

count_vcf_variants() {
  local vcf="$1"
  if command -v bcftools >/dev/null 2>&1; then
    bcftools view -H "$vcf" | wc -l
  else
    case "$vcf" in
      *.vcf.gz|*.vcf.bgz) zgrep -vc '^#' "$vcf" ;;
      *.vcf)              grep  -vc '^#' "$vcf" ;;
      *)                  echo 0 ;;
    esac
  fi
}

count_json_entries() {
  local jgz="$1"
  zcat "$jgz" 2>/dev/null | wc -l
}

printf "vcf_stem\tvcf_file\tvcf_variants\tjson_files\tjson_entries_total\n"

for vcf in "$VCF_DIR"/*.vcf "$VCF_DIR"/*.vcf.gz "$VCF_DIR"/*.vcf.bgz; do
  [[ -e "$vcf" ]] || continue

  base="$(basename "$vcf")"
  stem="$base"
  stem="${stem%.vcf}"
  stem="${stem%.vcf.gz}"
  stem="${stem%.vcf.bgz}"

  # Match: <stem>.<anything>.json.gz in JSON_DIR
  jsons=( "$JSON_DIR/${stem}".*.json.gz )

  vcf_n="$(count_vcf_variants "$vcf")"

  total=0
  for j in "${jsons[@]}"; do
    n="$(count_json_entries "$j")"
    total=$(( total + n ))
  done

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$stem" \
    "$vcf" \
    "$vcf_n" \
    "${#jsons[@]}" \
    "$total"
done | sort -t$'\t' -k1,1
