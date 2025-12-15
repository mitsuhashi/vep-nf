# vep-nf
Run VEP with nextflow in https://github.com/mitsuhashi/ensembl-vep

## 1. install

1. git cloneで必要なスクリプトをホームディレクトリ直下ににデプロイします。
```
mitsuhashi@a038:~/vep-nf$ cd
mitsuhashi@a038:~$ pwd
/home/mitsuhashi
mitsuhashi@a038:~$ git clone https://github.com/mitsuhashi/ensembl-vep
mitsuhashi@a038:~$ git clone https://github.com/mitsuhashi/vep-nf
mitsuhashi@a038:~$ cd vep-nf
mitsuhashi@a038:~/vep-nf$ pwd
/home/mitsuhashi/vep-nf
mitsuhashi@a038:~/vep-nf$ ls
00_run_vep.sh  README.md  vep.ini  vep_cache  vep_custom_annotations  vep_plugins
```

TogoVar用にパラメータが設定されているので、必要に応じて以下の2と3で設定を変更します。

（オプション）2. VEPのoptionは以下のvep.iniとコマンドラインで指定します。
```
mitsuhashi@a038:~/vep-nf$ head vep.ini
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

（オプション）3. nextflowの設定は、https://github.com/mitsuhashi/ensembl-vep/blob/release/115/nextflow/nextflow.config のファイルを変更します。

```
process { 
  cpus = 1
  memory = '16GB'
  time = '8h'

  withLabel: bcftools {
    container = 'quay.io/biocontainers/bcftools:1.13--h3a49de5_0'
  }
  withLabel: vep {
    container = vep_docker
    containerOptions = "-B $HOME/vep-nf/vep_cache:/opt/vep/cache,$HOME/deploy_vep_cache/reference_genome:/opt/vep/fasta,$HOME/vep-nf/vep_plugins:/opt/vep/plugins,$HOME/vep-nf/vep_plugins/cache:/opt/vep/plugins/cache,$HOME/vep-nf/vep_custom_annotations:/opt/vep/custom_annotations"
  }

  withName: 'NF_VEP:vep:runVEPonVCF' {
    containerOptions = "-B $HOME/vep-nf/work:$HOME/vep-nf/work,$HOME/vep-nf/vep_cache:/opt/vep/cache,$HOME/vep-nf/vep_plugins/cache:/opt/vep/plugins/cache,$HOME/vep-nf/vep_custom_annotations:/opt/vep/custom_annotations"
    publishDir = [
      path: params.outdir,
      mode: 'copy',
      overwrite: true,
      pattern: '*.json'
    ]
  }
}
```



### 2. run
1. --input で入力VCFのパスを指定します。それ以外のオプションのコマンドラインでvep.iniの内容を上書きできます。
```
mitsuhashi@a038:~/vep-nf$ cat 00_run_vep.sh
# このスクリプトのディレクトリ
DIR="$(cd "$(dirname "$0")" && pwd)"

# Run Ensembl VEP 115.0 using SLURM and Singularity
#  --input ${DIR}/../ensembl-vep/examples/homo_sapiens_GRCh38_mini.vcf.gz \
#  --input ${DIR}/../togovar_vcf/grch38/clinvar.vcf.gz \
#  --input ${DIR}/../togovar_vcf/grch38/gnomad.v4.1.sv.sites.vcf.gz \
nextflow run ${DIR}/../ensembl-vep \
  -profile slurm,singularity \
  --vep_config ${DIR}/vep.ini \
  --vep_version 115.0 \
  --cache_version 115 \
  --bin_size 100000 \
  --assembly GRCh38 \
  --input ${DIR}/../togovar_vcf/grch38/rs671.vcf.gz \
  --merge false \
  --resume
mitsuhashi@a038:~/vep-nf$
```

2.  00_run_vep.shを実行します。

```
mitsuhashi@a038:~/vep-nf$ ./00_run_vep.sh

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
mitsuhashi@a038:~/vep-nf$ cat outdir/rs671.vcf-vep-out.json | jq | head -20
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
