#!/usr/bin/env bash
set -euo pipefail

export CACHE_DIR=$HOME/vep-nf/vep_cache

singularity pull vep_115.sif docker://ensemblorg/ensembl-vep:release_115.0
singularity exec -B "$CACHE_DIR":/opt/vep/cache vep_115.sif INSTALL.pl -a cf -s homo_sapiens_merged -y GRCh38 -c /opt/vep/cache
singularity exec -B "$CACHE_DIR":/opt/vep/cache vep_115.sif INSTALL.pl -a cf -s homo_sapiens_merged -y GRCh37 -c /opt/vep/cache
