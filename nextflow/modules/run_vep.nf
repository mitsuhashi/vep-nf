process runVEP {

  tag "$original"
  cpus params.cpus
  label 'vep'
  cache 'lenient'

  // 1チャンク失敗で全体 abort しない（B運用の肝）
  errorStrategy 'ignore'

  // JSON.gz だけ outdir 直下へコピー
  publishDir { "${meta.output_dir}" }, mode: 'copy', overwrite: true, saveAs: { fname ->
    fname.endsWith('.json.gz') ? fname : null
  }

  input:
  tuple val(meta), val(original), path(vcf), path(vcf_index), path(vep_config)

  output:
  // 成功したものだけ *.json.gz が出る（失敗チャンクは emit されない）
  tuple val(meta), val(original), path(vcf), path("*.json.gz"), val(vep_config)

  script:
  """
  set -euo pipefail

  one_to_many='${meta.one_to_many}'

  # 元VCF名（prefixにしたい）
  orig_stem=\$(basename "${original}" | sed -E 's/\\.vcf(\\.b?gz)?\$//')

  # splitVCF が作るチャンク名（out.xaaaa など）
  chunk_stem=\$(basename "${vcf}" | sed -E 's/\\.vcf(\\.b?gz)?\$//')

  ini_stem=\$(basename "${vep_config}" | sed -E 's/\\.ini\$//')

  if [[ "\$one_to_many" == "true" ]]; then
    json_prefix="\${orig_stem}.\${chunk_stem}_\${ini_stem}"
  else
    json_prefix="\${orig_stem}.\${chunk_stem}"
  fi

  # VEP はまず .json に出して gzip
  vep \\
    --config "${vep_config}" \\
    --input_file "${vcf}" \\
    --output_file "\${json_prefix}.json"

  gzip -f "\${json_prefix}.json"
  """
}
