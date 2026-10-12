#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// -----------------------
// defaults (WARN回避)
// -----------------------
params.bin_size      = params.bin_size ?: 100
params.cpus          = params.cpus ?: 1
params.outdir        = params.outdir ?: 'outdir'
params.rerun_failed  = params.rerun_failed ?: false
params.failed_chunks = params.failed_chunks ?: null
params.isolate_failed_entries = params.isolate_failed_entries ?: false

// -----------------------
// Processes
// -----------------------

process checkVCF {
  tag { meta.vcf_stem }
  cpus params.cpus
  label 'vep'

  input:
  tuple val(meta), path(vcf), path(vep_config)

  output:
  tuple val(meta), path("normalized.vcf.gz"), path("normalized.vcf.gz.tbi"), path(vep_config)

  script:
  """
  set -euo pipefail

  in="${vcf}"
  out="normalized.vcf.gz"

  case "\$in" in
    *.vcf.gz|*.vcf.bgz)
      zcat "\$in" | bgzip -c > "\$out"
      ;;
    *.vcf)
      bgzip -c "\$in" > "\$out"
      ;;
    *)
      echo "ERROR: unexpected input: \$in" >&2
      exit 1
      ;;
  esac

  tabix -f -p vcf "\$out"

  # quick sanity check
  mapfile -t contigs < <(tabix -l "\$out" || true)
  chr="\${contigs[0]:-}"
  [[ -n "\$chr" ]] || { echo "ERROR: no contigs in \$out" >&2; exit 1; }
  tabix "\$out" "\${chr}:1-10001" >/dev/null || true
  """
}

process generateSplits {
  tag { meta.vcf_stem }
  cpus params.cpus
  label 'bcftools'

  input:
  tuple val(meta), path(vcf_gz), path(vcf_tbi), path(vep_config)

  output:
  tuple val(meta), path(vcf_gz), path(vcf_tbi), path("x*"), path(vep_config)

  script:
  """
  set -euo pipefail
  bcftools query -f'%CHROM\\t%POS\\n' "${vcf_gz}" \\
    | uniq \\
    | split -a 4 -l ${params.bin_size}
  """
}

process splitVCF {
  tag { "${meta.vcf_stem}:${split_file.getName()}" }
  cpus params.cpus
  label 'bcftools'

  input:
  tuple val(meta), path(vcf_gz), path(vcf_tbi), path(split_file), path(vep_config)

  output:
  tuple val(meta), path("chunk.vcf.gz"), path("chunk.vcf.gz.tbi"), path(vep_config)

  afterScript 'rm -f x* || true'

  script:
  def chunk = split_file.getName()
  """
  set -euo pipefail

  # split_file は "CHROM\\tPOS" のリスト
  bcftools view --no-version -T "${split_file}" -Oz "${vcf_gz}" > chunk.vcf.gz
  tabix -f -p vcf chunk.vcf.gz
  """
}

process runVEPonVCF {
  tag { "${meta.vcf_stem}:${meta.chunk_stem}" }
  cpus params.cpus
  label 'vep'

  errorStrategy 'ignore'

  input:
  tuple val(meta), path(vcf_chunk), path(vcf_chunk_tbi), path(vep_config)

  output:
  tuple val(meta),
      path("${meta.vcf_stem}.${meta.chunk_stem}.json.gz", optional: true),
      path("status.${meta.vcf_stem}.${meta.chunk_stem}.tsv")

  script:
  def status = "status.${meta.vcf_stem}.${meta.chunk_stem}.tsv"
  """
  set -euo pipefail

  json_prefix="${meta.vcf_stem}.${meta.chunk_stem}"
  status="${status}"

  set +e
  vep --config "${vep_config}" --input_file "${vcf_chunk}" --output_file "\${json_prefix}.json"
  rc=\$?
  set -e

  vcf_n=\$(zgrep -vc '^#' "${vcf_chunk}" 2>/dev/null || true)

  json_n=0
  if [[ -s "\${json_prefix}.json" ]]; then
    json_n=\$(wc -l < "\${json_prefix}.json" | tr -d ' ')
  fi

  if [[ \$rc -eq 0 && -s "\${json_prefix}.json" && "\$vcf_n" -eq "\$json_n" ]]; then
    gzip -f "\${json_prefix}.json"
    printf "%s\\t%s\\tOK\\t%d\\t%d\\t%d\\n" "${meta.vcf_stem}" "${meta.chunk_stem}" "\$rc" "\$vcf_n" "\$json_n" > "\$status"
  else
    gzip -f "\${json_prefix}.json"
    printf "%s\\t%s\\tFAIL\\t%d\\t%d\\t%d\\n" "${meta.vcf_stem}" "${meta.chunk_stem}" "\$rc" "\$vcf_n" "\$json_n" > "\$status"
  fi

  exit 0
  """
}

process summarizeFailedChunks {
  tag { meta.vcf_stem }
  cpus 1
  label 'bcftools'

  input:
  tuple val(meta), path(status_files)

  output:
  tuple val(meta),
        path("qc/status.tsv"),
        path("qc/failed-chunks.tsv")

  publishDir { "${params.outdir}/${meta.vcf_stem}" }, mode: 'copy', overwrite: true

  script:
  """
  set -euo pipefail
  mkdir -p qc

  printf "vcf_stem\\tchunk_stem\\tstatus\\trc\\tvcf_n\\tjson_n\\n" > qc/status.tsv
  : > qc/failed-chunks.tsv

  for f in ${status_files}; do
    line=\$(tr -d '\\r' < "\$f" | head -n1 || true)
    [[ -n "\$line" ]] || continue

    echo "\$line" >> qc/status.tsv

    st=\$(echo "\$line" | cut -f3)
    if [[ "\$st" != "OK" ]]; then
      echo "\$line" | cut -f1,2 >> qc/failed-chunks.tsv
    fi
  done
  """
}

process isolateFailedEntries {
  tag { "${meta.vcf_stem}:${meta.chunk_stem}" }
  cpus params.cpus
  label 'vep'

  errorStrategy 'ignore'

  input:
  tuple val(meta), path(vcf_chunk), path(vcf_chunk_tbi), path(vep_config)

  output:
  tuple val(meta), path("isolate-status.${meta.vcf_stem}.${meta.chunk_stem}.tsv")

  script:
  def status = "isolate-status.${meta.vcf_stem}.${meta.chunk_stem}.tsv"
  """
  set -euo pipefail

  status="${status}"
  printf "vcf_stem\\tchunk_stem\\trecord_index\\tchrom\\tpos\\tid\\tref\\talt\\tstatus\\trc\\tjson_n\\treason\\n" > "\$status"

  gzip -cd "${vcf_chunk}" | awk '/^#/ {print}' > header.vcf
  gzip -cd "${vcf_chunk}" | awk -v OFS='\\t' '!/^#/ {print ++n, \$0}' > records.tsv

  while IFS=\$'\\t' read -r record_index chrom pos id ref alt rest; do
    rm -f single.vcf single.json single.json.gz
    cp header.vcf single.vcf
    printf "%s\\t%s\\t%s\\t%s\\t%s" "\$chrom" "\$pos" "\$id" "\$ref" "\$alt" >> single.vcf
    if [[ -n "\${rest:-}" ]]; then
      printf "\\t%s" "\$rest" >> single.vcf
    fi
    printf "\\n" >> single.vcf

    set +e
    vep --config "${vep_config}" --input_file single.vcf --output_file single.json
    rc=\$?
    set -e

    json_n=0
    if [[ -s single.json ]]; then
      json_n=\$(wc -l < single.json | tr -d ' ')
    fi

    if [[ \$rc -eq 0 && -s single.json && "\$json_n" -eq 1 ]]; then
      printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\tOK\\t%d\\t%d\\t%s\\n" \
        "${meta.vcf_stem}" "${meta.chunk_stem}" "\$record_index" "\$chrom" "\$pos" "\$id" "\$ref" "\$alt" "\$rc" "\$json_n" "." >> "\$status"
    else
      reason="vep_failed_or_missing_json"
      if [[ \$rc -eq 0 && -s single.json && "\$json_n" -ne 1 ]]; then
        reason="json_count_mismatch"
      fi
      printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\tFAIL\\t%d\\t%d\\t%s\\n" \
        "${meta.vcf_stem}" "${meta.chunk_stem}" "\$record_index" "\$chrom" "\$pos" "\$id" "\$ref" "\$alt" "\$rc" "\$json_n" "\$reason" >> "\$status"
    fi
  done < records.tsv
  """
}

process summarizeIsolatedEntries {
  tag { meta.vcf_stem }
  cpus 1
  label 'bcftools'

  input:
  tuple val(meta), path(status_files)

  output:
  tuple val(meta),
        path("qc/isolate-status.tsv"),
        path("qc/failed-entries.tsv")

  publishDir { "${params.outdir}/${meta.vcf_stem}" }, mode: 'copy', overwrite: true

  script:
  """
  set -euo pipefail
  mkdir -p qc

  printf "vcf_stem\\tchunk_stem\\trecord_index\\tchrom\\tpos\\tid\\tref\\talt\\tstatus\\trc\\tjson_n\\treason\\n" > qc/isolate-status.tsv
  : > qc/failed-entries.tsv

  for f in ${status_files}; do
    tail -n +2 "\$f" >> qc/isolate-status.tsv
  done

  awk -F'\\t' 'NR == 1 || \$9 != "OK"' qc/isolate-status.tsv > qc/failed-entries.tsv
  """
}

// -----------------------
// Workflow (names keep: NF_VEP:vep:*)
// -----------------------
workflow vep {

  main:
    if (!params.input)      error "ERROR: --input FILE|DIR is required"
    if (!params.vep_config) error "ERROR: --vep_config INI is required"

    def vep_ini = file(params.vep_config)
    if (!vep_ini.exists()) error "ERROR: --vep_config not found: ${params.vep_config}"

    def in_path = file(params.input)

    // input VCF list (file or directory)
    def vcf_ch = in_path.isDirectory()
      ? Channel.fromPath("${in_path}/*.{vcf,vcf.gz,vcf.bgz}", checkIfExists: true)
      : Channel.fromPath("${in_path}", checkIfExists: true)

    vcf_inputs =
      vcf_ch
        .map { f ->
          def name = f.getName()
          def stem = name.replaceFirst(/\.vcf(\.(gz|bgz))?$/, '')
          def meta = [ vcf_stem: stem, index_type: 'tbi' ]
          tuple(meta, f, vep_ini)
        }

    checked = checkVCF(vcf_inputs)

    splits =
      generateSplits(checked)
        .transpose()
        .map { meta, vcf_gz, vcf_tbi, split_file, vep_config ->
          // split_file は xaaaa 等
          def meta2 = meta + [ chunk_stem: split_file.getName() ]
          tuple(meta2, vcf_gz, vcf_tbi, split_file, vep_config)
        }

    chunks =
      splitVCF(splits)
        .map { meta, chunk_vcf, chunk_tbi, vep_config ->
          tuple(meta, chunk_vcf, chunk_tbi, vep_config)
        }

    // rerun_failed/isolate_failed_entries: failed-chunks.tsv の (vcf_stem\tchunk_stem) のみ通す
    chunks_for_vep = chunks
    if (params.rerun_failed || params.isolate_failed_entries) {
      if (!params.failed_chunks) error "ERROR: --failed_chunks is required with --rerun_failed or --isolate_failed_entries"
      def fc = file(params.failed_chunks)
      if (!fc.exists()) error "ERROR: --failed_chunks not found: ${params.failed_chunks}"

      def failed_set = fc.readLines()
        .collect { it.trim() }
        .findAll { it && !it.startsWith('#') }
        .collect { it.split(/\t/)[0] + "\t" + it.split(/\t/)[1] }
        as Set

      chunks_for_vep =
        chunks_for_vep.filter { meta, vcf_chunk, vcf_chunk_tbi, vep_config ->
          failed_set.contains("${meta.vcf_stem}\t${meta.chunk_stem}".toString())
        }
   
    }

    if (params.isolate_failed_entries) {
      isolated_status =
        isolateFailedEntries(chunks_for_vep)
          .map { meta2, status_file -> tuple(meta2, status_file) }

      isolated_by_vcf =
        isolated_status
          .map { meta2, status_file ->
            def meta_vcf = [ vcf_stem: meta2.vcf_stem ]
            tuple(meta_vcf, status_file)
          }
          .groupTuple()

      summarizeIsolatedEntries(isolated_by_vcf)
    } else {
      // group status files per VCF then write qc files
      // runVEPonVCF の戻りを (meta, status_file) に落とす
      vep_status =
        runVEPonVCF(chunks_for_vep)
          .map { meta2, json_gz, status_file -> tuple(meta2, status_file) }

      // vcf単位でグループ化して (meta, [status_files...]) にする
      status_by_vcf =
      vep_status
        .map { meta2, status_file ->
          def meta_vcf = [ vcf_stem: meta2.vcf_stem ]   // ★ここがポイント（chunk_stemを落とす）
          tuple(meta_vcf, status_file)
        }
        .groupTuple()

      summarizeFailedChunks(status_by_vcf)
    }
}

workflow NF_VEP {
  main:
    vep()
}
