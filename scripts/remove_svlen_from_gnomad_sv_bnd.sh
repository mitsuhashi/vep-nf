#!/usr/bin/env bash
set -euo pipefail

# fix_bnd_end_svlen_batch.sh
#
# For each input VCF(.gz), replace BND records by removing INFO/END and INFO/SVLEN,
# keeping everything else unchanged, and write <input>.bndfixed.vcf.gz (+ .tbi).
#
# Requirements: bcftools, bgzip, tabix
#
# Usage:
#   ./fix_bnd_end_svlen_batch.sh gnomad_sv.chr*.vcf.gz
#   # or
#   ls gnomad_sv.chr*.vcf.gz | ./fix_bnd_end_svlen_batch.sh
#
# Notes:
# - Output is sorted and indexed.
# - Original input files are overwritten by Output.

die(){ echo "ERROR: $*" >&2; exit 1; }

command -v bcftools >/dev/null 2>&1 || die "bcftools not found"
command -v bgzip    >/dev/null 2>&1 || die "bgzip not found"
command -v tabix    >/dev/null 2>&1 || die "tabix not found"

inputs=()
if [[ $# -gt 0 ]]; then
  inputs=("$@")
else
  while IFS= read -r line; do
    [[ -n "$line" ]] && inputs+=("$line")
  done
fi

[[ ${#inputs[@]} -gt 0 ]] || die "No input VCFs provided"

for IN in "${inputs[@]}"; do
  [[ -f "$IN" ]] || die "Input not found: $IN"
  [[ "$IN" == *.vcf.gz ]] || die "Input must end with .vcf.gz: $IN"

  OUT="${IN%.vcf.gz}.vcf.gz"

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  nonbnd="$tmpdir/nonbnd.vcf.gz"
  bndfix="$tmpdir/bnd.fixed.vcf.gz"
  merged="$tmpdir/merged.unsorted.vcf.gz"

  # 1) Non-BND + records without SVTYPE (keep as-is)
  bcftools view -i 'INFO/SVTYPE!="BND"' "$IN" -Oz -o "$nonbnd"
  tabix -p vcf "$nonbnd"

  # 2) BND only, drop END and SVLEN
  bcftools view -i 'INFO/SVTYPE="BND"' "$IN" \
    | bcftools annotate -x INFO/END,INFO/SVLEN \
    | bgzip -c > "$bndfix"
  tabix -p vcf "$bndfix"

  # 3) Concatenate and sort
  bcftools concat -a -Oz -o "$merged" "$nonbnd" "$bndfix"
  bcftools sort -Oz -o "$OUT" "$merged"
  tabix -p vcf "$OUT"

  rm -rf "$tmpdir"
  trap - EXIT

  echo "OK: $IN -> $OUT"
done
