# vep-nf
Run VEP with nextflow at the NIG super computers

## 1. install

1. git cloneで必要なスクリプトを**ホームディレクトリ直下**ににデプロイします。
```
mitsuhashi@a038:~$ pwd
/home/mitsuhashi
mitsuhashi@a038:~$ git clone https://github.com/mitsuhashi/vep-nf
mitsuhashi@a038:~$ ls -l vep-nf
total 12804
-rw-r--r--   1 mitsuhashi sg-dbcls     4168 Dec 27 14:39 README.md
drwxr-xr-x  76 mitsuhashi sg-dbcls   413696 Jan 14 12:26 grch37
drwxr-xr-x 103 mitsuhashi sg-dbcls 12578816 Jan 13 22:07 grch38
drwxr-xr-x   3 mitsuhashi sg-dbcls     4096 Jan 16 15:10 nextflow
drwxr-xr-x   2 mitsuhashi sg-dbcls    36864 Jan 14 12:26 reports
-rwxr-xr-x   1 mitsuhashi sg-dbcls      809 Jan 13 23:03 run_vep_grch37.sh
-rwxr-xr-x   1 mitsuhashi sg-dbcls     1179 Jan 16 15:04 run_vep_grch38.sh
drwxr-xr-x   4 mitsuhashi sg-dbcls     4096 Jan 15 00:01 scripts
drwxr-xr-x   2 mitsuhashi sg-dbcls     4096 Jan  1 19:04 singularity
drwxr-xr-x   3 mitsuhashi sg-dbcls     4096 Jan 16 15:04 vep_cache
drwxr-xr-x   3 mitsuhashi sg-dbcls     4096 Jan  7 07:59 vep_custom_annotations
-rw-r--r--   1 mitsuhashi sg-dbcls      559 Jan 13 23:19 vep_grch37.ini
-rw-r--r--   1 mitsuhashi sg-dbcls     1248 Jan  7 08:02 vep_grch38.ini
drwxr-xr-x   4 mitsuhashi sg-dbcls     4096 Jan  1 19:57 vep_plugins
drwxr-xr-x   2 mitsuhashi sg-dbcls    12288 Jan 16 15:12 work
mitsuhashi@a038:~$
```

TogoVar用にパラメータが設定されているので、必要に応じて以下の2と3で設定を変更します。

（オプション）2. VEPのoptionは以下のvep_grch38.iniおよびvep_grch37.iniとコマンドラインで指定します。
```
mitsuhashi@a038:~/vep-nf$ head vep_grch38.ini
# basic
verbose 1
species homo_sapiens
format vcf
json 1

# reference/cache
offline 1
cache 1
dir_cache /opt/vep/cache
mitsuhashi@a038:~/vep-nf$
```

（オプション）3. nextflowの設定は、vep-nf/nextflow/nextflow.config を変更します。
以下のあたりが変更箇所です。コンテナにマウントするディレクトリの指定や割り当てメモリ、同時実行数などを指定します。
```
process {
  cpus = 1
  memory = '32 GB'
  time = '24h'

  withLabel: bcftools {
    container = 'quay.io/biocontainers/bcftools:1.13--h3a49de5_0'
  }

  withLabel: vep {
    container = vep_docker
    containerOptions = "-B $HOME/vep-nf/vep_cache:/opt/vep/cache,$HOME/deploy_vep_cache/reference_genome:/opt/ve
p/fasta,$HOME/vep-nf/vep_plugins:/opt/vep/plugins,$HOME/vep-nf/vep_plugins/cache:/opt/vep/plugins/cache,$HOME/ve
p-nf/vep_custom_annotations:/opt/vep/custom_annotations"
  }

  withName: 'NF_VEP:vep:runVEPonVCF' {
    containerOptions = "-B $HOME/vep-nf/grch38:$HOME/vep-nf/grch38,$HOME/vep-nf/grch37:$HOME/vep-nf/grch37,$HOME
/vep-nf/vep_cache:/opt/vep/cache,$HOME/vep-nf/vep_plugins/cache:/opt/vep/plugins/cache,$HOME/vep-nf/vep_custom_a
nnotations:/opt/vep/custom_annotations"
    publishDir = [
      path: params.outdir,
      mode: 'copy',
      overwrite: true,
      pattern: '*.json.gz'
    ]
  }
}
```



### 2. run (GRCh38の場合)
1. --input で入力VCFのパス（ディレクトリまたはVCFファイル単体）を指定します。それ以外のオプションのコマンドラインでvep.iniの内容を上書きできます。
```
mitsuhashi@a038:~/vep-nf$ cat run_vep_grch38.sh
#!/bin/bash

set -euo pipefail

# このスクリプトのディレクトリ
DIR="$(cd "$(dirname "$0")" && pwd)"

#VCF=/home/mitsuhashi/togovar_vcf/grch38/gnomad.exomes.v4.1.noinfo.sites.chr22.vcf.bgz
#VCF=/home/mitsuhashi/togovar_vcf/test/jogo.chr1.vcf.gz
#VCF=/home/mitsuhashi/togovar_vcf/test/rs671.vcf.bgz
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
  -resume \
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
  --failed_chunks "${DIR}/grch38/jogo.chr22_100/qc/failed-chunks.tsv" \
  --rerun_failed \
  -resume
}

run
#run_failed_chunks
mitsuhashi@a038:~/vep-nf$
```

2. run_vep_grch38.shを実行します。

```
mitsuhashi@a038:~/vep-nf$ ./run_vep_grch38.sh

 N E X T F L O W   ~  version 25.10.2

Using image ensemblorg/ensembl-vep:release_115.0
Launching `/home/mitsuhashi/vep-nf/../ensembl-vep/main.nf` [elegant_almeida] DSL2 - revision: af2539a497

executor >  slurm (4)
[e5/efd251] NF_VEP:vep:checkVCF (1)       [100%] 1 of 1 ✔
[5a/3de2d4] NF_VEP:vep:generateSplits (1) [100%] 1 of 1 ✔
[33/c1b68c] NF_VEP:vep:splitVCF (1)       [100%] 1 of 1 ✔
[57/9db65c] NF_VEP:vep:runVEPonVCF (null) [100%] 1 of 1 ✔

mitsuhashi@a038:~/vep-nf$
```
3. 出力JSONファイルを確認します。

```
mitsuhashi@a038:~/vep-nf$ cat grch38/*.json.gz| jq | head -20
{
  "strand": 1,
  "variant_class": "SNV",
  "allele_string": "G/A",
  "start": 111803962,
  "transcript_consequences": [
    {
      "cds_start": 1510,
      "mane_select": "NM_000690.4",
      "impact": "MODERATE",
      "alphamissense": {
        "am_class": "likely_pathogenic",
        "am_pathogenicity": 0.8864
      },
      "cadd_raw": 5.37132,
      "codons": "Gaa/Aaa",
      "sift_score": 0,
      "sift_prediction": "deleterious_low_confidence",
      "gene_symbol": "ALDH2",
      "strand": 1,
mitsuhashi@a038:~/vep-nf$
```
