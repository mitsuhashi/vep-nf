#!/usr/bin/bash
#
set -euo pipefail

mkdir -p ./cache/CADD/v1.7/GRCh38
wget -O ./cache/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz
wget -O ./cache/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz.tbi -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz.tbi
wget -O ./cache/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz
wget -O ./cache/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz.tbi -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz.tbi
