#!/usr/bin/bash
#
set -euo pipefail

#
# CADD
#

#mkdir -p ./cache/CADD/v1.7/GRCh38
#wget -O ./cache/CADD/v1.7/GRCh38/GRCh38-v1.7_noanno_prevScored.tsv.gz -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38-v1.7_noanno_prevScored.tsv.gz 
#wget -O ./cache/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz
#wget -O ./cache/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz.tbi -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz.tbi
#wget -O ./cache/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz
#wget -O ./cache/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz.tbi -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz.tbi
#

#mkdir -p ./cache/CADD/v1.7/GRCh37
#wget -O ./cache/CADD/v1.7/GRCh37/GRCh37-v1.7_noanno_prevScored.tsv.gz -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh37-v1.7_noanno_prevScored.tsv.gz
wget -O ./cache/CADD/v1.7/GRCh37/whole_genome_SNVs.tsv.gz -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh37/whole_genome_SNVs.tsv.gz
wget -O ./cache/CADD/v1.7/GRCh37/whole_genome_SNVs.tsv.gz.tbi -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh37/whole_genome_SNVs.tsv.gz.tbi
wget -O ./cache/CADD/v1.7/GRCh37/gnomad.genomes.r4.0.indel.tsv.gz -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh37/gnomad.genomes.r4.0.indel.tsv.gz
wget -O ./cache/CADD/v1.7/GRCh37/gnomad.genomes.r4.0.indel.tsv.gz.tbi -U "Mozilla/5.0" https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh37/gnomad.genomes.r4.0.indel.tsv.gz.tbi
#



#
# CADD-SV GRCh38 only
#
#mkdir -p ./cache/CADD-SV/v1.1
#BASE=https://kircherlab.bihealth.org/download/CADD-SV/v1.1

#wget -c -U "Mozilla/5.0" -P ./cache/CADD-SV/v1.1 \
#  $BASE/prescored_variants.tsv.gz \
#  $BASE/prescored_variants.tsv.gz.tbi
#


#
# dbNSFP
#
#wget -O ./cache/dbNSFP/ -U "Mozilla/5.0" https://dist.genos.us/academic/b2fd38/dbNSFP5.3a_grch38.gz
#wget -O ./cache/dbNSFP/ -U "Mozilla/5.0" https://dist.genos.us/academic/b2fd38/dbNSFP5.3a_grch38.gz.tbi
#wget -O ./cache/dbNSFP/ -U "Mozilla/5.0" https://dist.genos.us/academic/b2fd38/dbNSFP5.3a_grch38.gz.md5

#wget -O ./cache/dbNSFP/ -U "Mozilla/5.0" https://dist.genos.us/academic/b2fd38/dbNSFP5.3a_grch37.gz
#wget -O ./cache/dbNSFP/ -U "Mozilla/5.0" https://dist.genos.us/academic/b2fd38/dbNSFP5.3a_grch37.gz.tbi
#wget -O ./cache/dbNSFP/ -U "Mozilla/5.0" https://dist.genos.us/academic/b2fd38/dbNSFP5.3a_grch37.gz.md5
