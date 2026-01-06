process summarizeQc {
  tag "summarizeQc"
  cpus 1
  label 'vep'
  cache 'lenient'

  publishDir { "${outdir}/qc" }, mode: 'copy', overwrite: true

  input:
  val outdir
  path matchfiles

  output:
  path "all-match.txt", emit: all_match
  path "failed-chunks.txt", emit: failed_chunks

  script:
  """
  set -euo pipefail

  : > all-match.txt
  : > failed-chunks.txt

  for f in ${matchfiles}; do
    cat "\$f" >> all-match.txt

    if grep -qx '^FALSE\$' "\$f"; then
      b=\$(basename "\$f")
      echo "\${b%-match.txt}" >> failed-chunks.txt
    fi
  done
  """
}

process failIfFailedChunks {
  tag "failIfFailedChunks"
  cpus 1
  label 'vep'
  cache 'lenient'

  input:
  path failed_chunks

  script:
  """
  set -euo pipefail

  n=\$(grep -c '.' "${failed_chunks}" || true)
  if [[ "\$n" -gt 0 ]]; then
    echo "ERROR: Found \$n failed chunk(s). See outdir/qc/failed-chunks.txt and outdir/qc/*-countcheck.tsv" >&2
    exit 1
  fi
  """
}
