# このスクリプトのディレクトリ
DIR="$(cd "$(dirname "$0")" && pwd)"

# Run Ensembl VEP 115.0 using SLURM and Singularity
#  --input ${DIR}/../togovar_vcf/grch38/gnomad.v4.1.sv.sites_0000.vcf.gz \
#  --input ${DIR}/../ensembl-vep/examples/homo_sapiens_GRCh38_mini.vcf.gz \
#  --input ${DIR}/../togovar_vcf/grch38/clinvar.vcf.gz \
#  --input ${DIR}/../togovar_vcf/grch38/rs671.vcf.gz \
nextflow run ${DIR}/../ensembl-vep \
  -profile slurm,singularity \
  --vep_config ${DIR}/vep.ini \
  --vep_version 115.0 \
  --cache_version 115 \
  --bin_size 100000 \
  --assembly GRCh38 \
  --input ${DIR}/../togovar_vcf/grch38/gnomad.v4.1.sv.sites.vcf.gz \
  --merge false \
  --resume
