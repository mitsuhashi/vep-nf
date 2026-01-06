process verifyVcfJsonCounts {
  tag "${original}"

  cpus 1
  label 'vep'
  cache 'lenient'

  publishDir { "${meta.output_dir}/qc" },
    mode: 'copy',
    overwrite: true,
    saveAs: { fname ->
      ( fname.endsWith('-match.txt') || fname.endsWith('-countcheck.tsv') ) ? fname : null
    }

  input:
  tuple val(meta), val(original), path(vcf), path(json_gz)

  output:
  path("*-match.txt"), emit: matchfiles
  path("*-countcheck.tsv"), optional: true, emit: reports

  script:
  def orig_stem  = file(original).getName().replaceFirst(/\.vcf(\.b?gz)?$/, '')
  def chunk_stem = file(vcf).getName().replaceFirst(/\.vcf(\.b?gz)?$/, '')
  def chunk_prefix = "${orig_stem}.${chunk_stem}"

  def match_file = "${chunk_prefix}-match.txt"
  def qc_file    = "${chunk_prefix}-countcheck.tsv"

  """
  set -euo pipefail

  if [[ "${vcf}" =~ \\.gz\$ || "${vcf}" =~ \\.bgz\$ ]]; then
    vcf_n=\$(gzip -cd "${vcf}" | grep -vc '^#')
  else
    vcf_n=\$(grep -vc '^#' "${vcf}")
  fi

  json_n=\$(
    for f in ${json_gz}; do
      gzip -cd "\$f" | wc -l
    done | awk '{s+=\$1} END{print s+0}'
  )

  if [[ "\$vcf_n" -eq "\$json_n" ]]; then
    echo "TRUE" > "${match_file}"
  else
    echo "FALSE" > "${match_file}"
    printf "original\\tchunk_vcf\\tjson\\tvcf_variants\\tjson_entries\\tmatch\\n" > "${qc_file}"
    printf "%s\\t%s\\t%s\\t%s\\t%s\\tFALSE\\n" "${original}" "${vcf}" "${json_gz}" "\$vcf_n" "\$json_n" >> "${qc_file}"
  fi
  """
}
