#!/usr/bin/env nextflow

/* 
 * Script to check if the files are bgzipped and bgzip if not
 */

import java.util.zip.GZIPInputStream
import java.util.zip.GZIPOutputStream

def checkVCFheader (f) {
  // Check file extension
  if (!(f  =~ '\\.vcf$') && !(f =~ '\\.vcf\\.b?gz$')) {
    return false
  }

  // Check if file is compressed
  if (f =~ '\\.b?gz$') {
    InputStream fileStream = new FileInputStream(f.toString())
    InputStream gzip = new GZIPInputStream(fileStream)
    Reader decoder = new InputStreamReader(gzip)
    BufferedReader data = new BufferedReader(decoder)
    lines = data.lines()
  } else {
    lines = f.readLines()
  }

  // Check file header
  is_vcf_format = false
  has_header = false
  for( line : lines ) {
    if (!line =~ '^#') {
      // stop inspecting file when reaching a line not starting with hash
      break
    } else if (line =~ '^##fileformat=') {
      is_vcf_format = true
    } else if (line =~ '^#CHROM') {
      has_header = true
    }
  }
  return is_vcf_format && has_header
}

process checkVCF {
  /*
  Function to check input VCF files

  Returns
  -------
  Tuple of VCF, VCF index, vep config file, a output dir, and the index type of VCF file
  */

  cpus params.cpus
  label 'vep'
  errorStrategy 'ignore'

  input:
  tuple val(meta), path(vcf), path(vcf_index), path(vep_config)
  
  output:
  tuple val(meta), path("*.gz", includeInputs: true), path ("*.gz.{tbi,csi}", includeInputs: true), path(vep_config)

  afterScript "rm -f *.vcf *.vcf.tbi *.vcf.csi tmp.vcf"

  script:

  // 入力: xxx.vcf / xxx.vcf.gz / xxx.vcf.bgz すべて受けて、出力名は xxx.vcf.gz に統一
  stem   = vcf.getName().replaceFirst(/\.vcf(\.(gz|bgz))?$/, '')
  out_vcf_gz = "${stem}.vcf.gz"

  sort_cmd = ""
  isGzipped = (vcf.extension in ['gz','bgz'])
  cat_cmd   = isGzipped ? "zcat ${vcf}" : "cat ${vcf}"
  if( params.sort ) {
    sort_cmd += "(${cat_cmd} | head -1000 | grep '^#'; ${cat_cmd} | grep -v '^#' | sort -k1,1d -k2,2n) > tmp.vcf; "
  }else{
    sort_cmd += "(${cat_cmd} > tmp.vcf; "
  } 
  sort_cmd += "bgzip -c tmp.vcf > ${out_vcf_gz})"

  """
  ${sort_cmd}
  tabix -f ${out_vcf_gz}

  # quickly test tabix -- ensures both bgzip and tabix are okay
  chr=\$(tabix -l *.gz | head -n1)
  tabix *.gz \${chr}:1-10001
  """
}
