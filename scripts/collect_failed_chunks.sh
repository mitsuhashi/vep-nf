#!/usr/bin/env bash
set -euo pipefail

# usage:
#   ./list_failed_chunks.sh /path/to/run_dir_or_work_dir [out_prefix]
# examples:
#   ./list_failed_chunks.sh /home/mitsuhashi/vep-nf/grch38/run/clinvar
#   ./list_failed_chunks.sh /lustre9/open/home/mitsuhashi/vep-nf/work failed

root="${1:-../work}"
prefix="${2:-failed-chunks}"

# 出力
out_tsv="${prefix}.tsv"   # vcf_stem<TAB>chunk_stem
out_txt="${prefix}.txt"   # vcf_stem.chunk_stem (1行1件)
out_all="${prefix}.all.tsv"  # 集計（最新判定後の全件）

declare -A best_mtime best_status best_rc

# status ファイルを集める（outdir配下/作業ディレクトリ配下どちらでもOK）
# ※ "status.<vcf>.<chunk>....tsv" のようなファイル名が多い前提
while IFS= read -r -d '' f; do
  # 空ファイルはスキップ
  [[ -s "$f" ]] || continue

  # mtime（同じチャンクの status が複数あれば、最新だけ採用）
  mt="$(stat -c %Y "$f" 2>/dev/null || echo 0)"

  line="$(head -n1 "$f" | tr -d '\r' || true)"
  [[ -n "$line" ]] || continue

  # タブ区切りを想定
  IFS=$'\t' read -r c1 c2 c3 c4 _rest <<< "$line"

  vcf=""
  chunk=""
  st=""
  rc=""

  # 形式A: vcf  chunk  OK|FAIL  rc
  if [[ "${c3:-}" == "OK" || "${c3:-}" == "FAIL" ]]; then
    vcf="$c1"; chunk="$c2"; st="$c3"; rc="${c4:-}"
  # 形式B: OK|FAIL  chunk  rc  (古い案の名残対策)
  elif [[ "${c1:-}" == "OK" || "${c1:-}" == "FAIL" ]]; then
    st="$c1"; chunk="$c2"; rc="${c3:-}"
    # vcf はファイル名から推定（status.<vcf>.<chunk>...tsv を想定）
    base="$(basename "$f")"
    # status.<vcf>.<chunk>.xxx.tsv -> <vcf> と <chunk> を取り出す
    vcf="$(echo "$base" | sed -E 's/^status\.([^.]+)\..*$/\1/')"
    # chunk は行から取れてる想定。取れない場合の保険：
    [[ -n "$chunk" ]] || chunk="$(echo "$base" | sed -E 's/^status\.[^.]+\.([^.]+)\..*$/\1/')"
  else
    # 想定外は無視（必要ならここで echo >&2 してもOK）
    continue
  fi

  [[ -n "$vcf" && -n "$chunk" && -n "$st" ]] || continue

  key="${vcf}"$'\t'"${chunk}"

  prev="${best_mtime[$key]:- -1}"
  if (( mt >= prev )); then
    best_mtime["$key"]="$mt"
    best_status["$key"]="$st"
    best_rc["$key"]="${rc:-}"
  fi
done < <(find "$root" -type f -name 'status.*.tsv' -print0 2>/dev/null)

# 全件（最新判定後）
{
  printf "vcf_stem\tchunk_stem\tstatus\trc\n"
  for key in "${!best_status[@]}"; do
    vcf="${key%%$'\t'*}"
    chunk="${key##*$'\t'}"
    st="${best_status[$key]}"
    rc="${best_rc[$key]}"
    printf "%s\t%s\t%s\t%s\n" "$vcf" "$chunk" "$st" "${rc:-}"
  done | LC_ALL=C sort -t $'\t' -k1,1 -k2,2
} > "$out_all"

# 失敗のみ（あなたの希望：VCF名+chunk名 形式）
awk -F'\t' 'NR>1 && $3!="OK"{print $1 "\t" $2}' "$out_all" > "$out_tsv"
awk -F'\t' 'NR>1 && $3!="OK"{print $1 "." $2}' "$out_all" > "$out_txt"

echo "Wrote:"
echo "  $out_all"
echo "  $out_tsv"
echo "  $out_txt"
