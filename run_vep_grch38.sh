#!/bin/bash

set -euo pipefail

# このスクリプトのディレクトリ
DIR="$(cd "$(dirname "$0")" && pwd)"

#VCF=/home/mitsuhashi/togovar_vcf/grch38/gnomad.exomes.v4.1.noinfo.sites.chr22.vcf.bgz
#VCF=/home/mitsuhashi/togovar_vcf/test/jogo.chr22.vcf.gz
#VCF=/home/mitsuhashi/togovar_vcf/test/rs671.vcf.bgz
#VCF=/home/mitsuhashi/togovar_vcf/test/jogo.chr22_100.vcf.gz
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
  --outdir "${DIR}/grch38" \
  -resume
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
  --failed_chunks "${DIR}/grch38/jogo.chr22_100/qc/failed-chunks.tsv" \
  --rerun_failed \
  -resume
}

run
#run_failed_chunks
