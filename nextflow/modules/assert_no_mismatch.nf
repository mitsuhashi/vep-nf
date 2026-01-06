process assertNoMismatch {
  tag "assertNoMismatch"

  cpus 1
  label 'vep'
  cache 'lenient'

  input:
  path(all_match)

  output:
  stdout emit: summary

  """
  set -euo pipefail
  n_false=\$(grep -c '^FALSE\$' "${all_match}" || true)
  n_true=\$(grep -c '^TRUE\$'  "${all_match}" || true)

  echo "QC summary: TRUE=\$n_true FALSE=\$n_false"

  if [[ "\$n_false" -gt 0 ]]; then
    echo "ERROR: Found \$n_false chunk(s) with count mismatch (see outdir/qc/*-countcheck.tsv)" >&2
    exit 1
  fi
  """
}
