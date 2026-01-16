#!/usr/bin/env python3
import argparse
import gzip
import io
import json
import re
import sys
from collections import defaultdict
from typing import Dict, Iterable, Iterator, List, Optional, Set, Tuple

ALLELEID_RE = re.compile(r'(?:^|;)ALLELEID=([^;]+)')

def open_text_maybe_gz(path: str) -> io.TextIOBase:
    if path.endswith(".gz"):
        return io.TextIOWrapper(gzip.open(path, "rb"), encoding="utf-8", errors="replace")
    return open(path, "r", encoding="utf-8", errors="replace")

def extract_alleleid_from_info(info: str) -> Optional[str]:
    m = ALLELEID_RE.search(info)
    if not m:
        return None
    return m.group(1).strip()

def iter_vcf_records(vcf_path: str) -> Iterator[Tuple[str, str, str, str, str, str]]:
    """
    yields: (alleleid, chrom, pos, vid, ref, alt)
    """
    with open_text_maybe_gz(vcf_path) as f:
        for line in f:
            if not line or line.startswith("#"):
                continue
            line = line.rstrip("\n")
            cols = line.split("\t")
            if len(cols) < 8:
                continue
            chrom, pos, vid, ref, alt, qual, flt, info = cols[:8]
            alleleid = extract_alleleid_from_info(info)
            if alleleid is None:
                continue
            yield (alleleid, chrom, pos, vid, ref, alt)

def iter_json_input_strings(json_path: str, key: str = "input") -> Iterator[str]:
    """
    JSONL想定: 各行がJSON。key の値(例: "input")がVCF-likeのタブ区切り文字列。
    """
    with open_text_maybe_gz(json_path) as f:
        for ln, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                # JSON全文が1行でないケースや、ログ混入などの可能性
                # 必要ならここでスキップせずに終了させてもよい
                continue
            if key not in obj:
                continue
            val = obj[key]
            if not isinstance(val, str):
                continue
            yield val

def extract_alleleids_from_json(json_path: str, key: str = "input") -> Set[str]:
    alleleids: Set[str] = set()
    for s in iter_json_input_strings(json_path, key=key):
        # "7\t75771943\t3139741\tG\tA\t.\t.\tAF_EXAC=...;ALLELEID=3292476;..."
        cols = s.split("\t")
        if len(cols) < 8:
            continue
        info = cols[7]
        alleleid = extract_alleleid_from_info(info)
        if alleleid is None:
            continue
        alleleids.add(alleleid)
    return alleleids

def main():
    ap = argparse.ArgumentParser(
        description="Find ALLELEID present in VCF but missing in JSON (match by INFO:ALLELEID)."
    )
    ap.add_argument("--vcf", required=True, help="Input VCF (.vcf/.vcf.gz/.vcf.bgz)")
    ap.add_argument("--json", required=True, help="Input JSONL (.jsonl/.json/.gz) each line is JSON")
    ap.add_argument("--json-key", default="input", help='JSON key containing VCF-like string (default: "input")')
    ap.add_argument("--out", default="-", help="Output TSV (default: stdout)")
    args = ap.parse_args()

    json_alleleids = extract_alleleids_from_json(args.json, key=args.json_key)

    # VCF側: alleleid -> list of (chrom,pos,id,ref,alt)
    vcf_map: Dict[str, List[Tuple[str, str, str, str, str]]] = defaultdict(list)
    for alleleid, chrom, pos, vid, ref, alt in iter_vcf_records(args.vcf):
        vcf_map[alleleid].append((chrom, pos, vid, ref, alt))

    missing = [aid for aid in vcf_map.keys() if aid not in json_alleleids]
    missing.sort(key=lambda x: int(x) if x.isdigit() else x)

    out_f = sys.stdout if args.out == "-" else open(args.out, "w", encoding="utf-8")
    try:
        # ヘッダ
        out_f.write("ALLELEID\tCHROM\tPOS\tVCF_ID\tREF\tALT\n")
        for aid in missing:
            for chrom, pos, vid, ref, alt in vcf_map[aid]:
                out_f.write(f"{aid}\t{chrom}\t{pos}\t{vid}\t{ref}\t{alt}\n")
    finally:
        if out_f is not sys.stdout:
            out_f.close()

if __name__ == "__main__":
    main()
