/*
 * modules/collect_vep_errors.nf
 *
 * Collect VEP task stderr from Nextflow work directories:
 *   work//.command.err  (or .command.out as fallback)
 *
 * Output:
 *   - vep_errors.txt : blocks with original/chunk/workdir + stderr excerpt
 *   - vep_errors.tsv : original/chunk/workdir/stderr_file
 *   - vep_errors.summary.txt
 */

nextflow.enable.dsl=2

process collectVepErrors {
  tag "collectVepErrors"
  executor 'local'
  cpus 1
  memory '1 GB'
  time '30m'

  // 各 run の outdir/qc に出したい（params.outdir が無ければ outdir/qc）
  publishDir { "${params.outdir ?: 'outdir'}/qc" }, mode: 'copy', overwrite: true

  input:
    val trigger
    val workroot
    val only_levels   // 1: ERROR/WARN/EXCEPTION っぽい行だけ、0: 全部

  output:
    path "vep_errors.txt", emit: txt, optional: true
    path "vep_errors.tsv", emit: tsv, optional: true

  script:
  """
  set -euo pipefail

  WORKROOT="${workroot}"
  ONLY_LEVELS="${only_levels}"

  : > vep_errors.txt
  printf "original\\tchunk\\tworkdir\\tstderr_file\\n" > vep_errors.tsv

  # .command.err（stderr）が non-empty のものを列挙
  mapfile -t ERRFILES < <(find "\$WORKROOT" -type f -name ".command.err" -size +0c 2>/dev/null | sort)

  # もし stderr が無い環境なら .command.out を fallback
  if [[ "\${#ERRFILES[@]}" -eq 0 ]]; then
    mapfile -t ERRFILES < <(find "\$WORKROOT" -type f -name ".command.out" -size +0c 2>/dev/null | sort)
  fi

  for err in "\${ERRFILES[@]}"; do
    d=\$(dirname "\$err")
    sh="\$d/.command.sh"

    # runVEP のタスクだけ拾う（他プロセスの stderr を混ぜない）
    if [[ ! -f "\$sh" ]]; then
      continue
    fi
    if ! grep -qiE '(^|[[:space:]/])vep([[:space:]]|\$)' "\$sh"; then
      continue
    fi

    chunk=""
    # vep の input をそれっぽく抽出（--input_file / --input / -i）
    chunk=\$(grep -Eo '(--input_file|--input|-i)[[:space:]]+[^[:space:]]+' "\$sh" | head -n1 | awk '{print \$2}' || true)
    chunk=\$(basename "\${chunk:-}")

    # fallback: .vcf/.vcf.gz/.vcf.bgz の最初の出現
    if [[ -z "\$chunk" ]]; then
      chunk=\$(grep -Eo '[^[:space:]]+\\.vcf(\\.b?gz)?' "\$sh" | head -n1 | xargs -r basename || true)
    fi

    original="\$chunk"
    # 例: jogo.chr22.out.xaaab.vcf.gz みたいな命名から original 推定（無理ならそのまま）
    if [[ "\$chunk" =~ ^(.+)\\.out\\.x[a-z]{4,} ]]; then
      original="\${BASH_REMATCH[1]}.vcf.gz"
    fi

    printf "%s\\t%s\\t%s\\t%s\\n" "\$original" "\$chunk" "\$d" "\$err" >> vep_errors.tsv

    {
      echo "### original=\$original  chunk=\$chunk  workdir=\$d"
      if [[ "\$ONLY_LEVELS" == "1" ]]; then
        if grep -E -i '(^\\s*ERROR|\\bERROR\\b|\\bFATAL\\b|\\bEXCEPTION\\b|\\bWARN\\b)' "\$err" >/dev/null; then
          grep -E -i '(^\\s*ERROR|\\bERROR\\b|\\bFATAL\\b|\\bEXCEPTION\\b|\\bWARN\\b)' "\$err"
        else
          cat "\$err"
        fi
      else
        cat "\$err"
      fi
      echo
    } >> vep_errors.txt
  done

  """
}
