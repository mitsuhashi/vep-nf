#!/bin/bash

set -euo pipefail

# このスクリプトのディレクトリ
DIR="$(cd "$(dirname "$0")" && pwd)"

#VCF=/home/mitsuhashi/togovar_vcf/grch38/gnomad.exomes.v4.1.noinfo.sites.chr22.vcf.bgz
#VCF=/home/mitsuhashi/togovar_vcf/test/jogo.chr1.vcf.gz
#VCF=/home/mitsuhashi/togovar_vcf/test/rs671.vcf.bgz
#VCF=/home/mitsuhashi/togovar_vcf/test/tgv181286516.vcf.gz
#VCF=/home/mitsuhashi/togovar_vcf/test/jogo.chr22_100.vcf.gz
#VCF=/home/mitsuhashi/togovar_vcf/grch38/clinvar.vcf.gz
#VCF=/home/mitsuhashi/togovar_vcf/grch38/clinvar.vcf.gz

VCF=/home/mitsuhashi/togovar_vcf/grch38

# 画像キャッシュは共通でOK（容量節約）
export NXF_SINGULARITY_CACHEDIR=./singularity

run() {

nextflow run nextflow \
  -profile slurm,singularity \
  -work-dir "./work" \
  --vep_config "${DIR}/vep_grch38.ini" \
  --input "$VCF" \
  --outdir "${DIR}/grch38"
}



#
# failed-chunkだけを再実行する
#
run_failed_chunks() {
nextflow run nextflow \
  -profile slurm,singularity \
  -work-dir "./work" \
  --vep_config "${DIR}/vep_grch38.ini" \
  --input "$VCF" \
  --outdir "${DIR}/grch38" \
  --failed_chunks "${DIR}/scripts/failed-chunks.tsv" \
  --rerun_failed
}

#
# failed-chunk内のVCFエントリーを1件ずつVEPにかけて原因entryを絞る
#
isolate_failed_entries() {
nextflow run nextflow \
  -profile slurm,singularity \
  -work-dir "./work" \
  --vep_config "${DIR}/vep_grch38.ini" \
  --input "$VCF" \
  --outdir "${DIR}/grch38" \
  --failed_chunks "${DIR}/scripts/failed-chunks.tsv" \
  --isolate_failed_entries
}

run
#run_failed_chunks
#isolate_failed_entries
