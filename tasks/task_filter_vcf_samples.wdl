version 1.0

task filter_vcf_samples {
  input {
    File vcf
    String collection_name
    Float max_missing_pct = 20.0
    Int memory = 8
    Int disk_size = 16
  }
  command <<<
    touch excluded_samples.txt
    touch vcf_input.txt

    python3 << 'CODE'
    import subprocess
    import sys
    import re

    vcf = "~{vcf}"
    max_missing_pct = ~{max_missing_pct}

    # Get sample list
    samples = subprocess.run(
        ["bcftools", "query", "-l", vcf],
        capture_output=True, text=True, check=True
    ).stdout.strip().split('\n')
    samples = [s for s in samples if s]

    # Count total variant sites
    total = int(subprocess.run(
        "bcftools view -H " + vcf + " | wc -l",
        shell=True, capture_output=True, text=True, check=True
    ).stdout.strip())

    if total == 0:
        print("WARNING: VCF has no variant sites; skipping sample filtering.", file=sys.stderr)
        with open("excluded_samples.txt", "w") as f:
            pass
        with open("keep_samples.txt", "w") as f:
            f.write('\n'.join(samples))
    else:
        # Fetch all sample/GT pairs in a single bcftools call
        result = subprocess.run(
            ["bcftools", "query", "-f", "[%SAMPLE\t%GT\n]", vcf],
            capture_output=True, text=True, check=True
        )
        missing_counts = {s: 0 for s in samples}
        for line in result.stdout.splitlines():
            parts = line.split('\t')
            if len(parts) == 2:
                sample, gt = parts
                if '.' in gt:
                    missing_counts[sample] = missing_counts.get(sample, 0) + 1

        excluded = []
        for sample in samples:
            pct = missing_counts.get(sample, 0) / total * 100
            if pct > max_missing_pct:
                excluded.append(sample)
                print(f"Excluding {sample}: {pct:.2f}% missing sites (threshold {max_missing_pct}%)")

        with open("excluded_samples.txt", "w") as f:
            for s in excluded:
                f.write(s + '\n')

        keep = [s for s in samples if s not in set(excluded)]
        if not keep:
            print("ERROR: All samples would be excluded by the missing data filter.", file=sys.stderr)
            sys.exit(1)
        with open("keep_samples.txt", "w") as f:
            f.write('\n'.join(keep))

    # Fix undefined INFO/FORMAT tags in the VCF header so bcftools -S can subset samples.
    # bcftools exits 255 if any tag is used in records but not declared in the header.
    vcf = "~{vcf}"
    header = subprocess.run(
        ["bcftools", "view", "-h", vcf], capture_output=True, text=True, check=True
    ).stdout
    defined_info = set(re.findall(r'##INFO=<ID=([^,>]+)', header))
    defined_fmt  = set(re.findall(r'##FORMAT=<ID=([^,>]+)', header))

    records = subprocess.run(
        ["bcftools", "view", "-H", vcf], capture_output=True, text=True, check=True
    ).stdout
    used_info, used_fmt = set(), set()
    for line in records.splitlines():
        cols = line.split('\t')
        if len(cols) > 7 and cols[7] not in ('.', ''):
            for f in cols[7].split(';'):
                t = f.split('=')[0].strip()
                if t:
                    used_info.add(t)
        if len(cols) > 8:
            for t in cols[8].split(':'):
                if t:
                    used_fmt.add(t)

    missing_info = sorted(used_info - defined_info)
    missing_fmt  = sorted(used_fmt  - defined_fmt)
    if missing_info or missing_fmt:
        extra = '\n'.join(
            [f'##INFO=<ID={t},Number=.,Type=String,Description="Undefined INFO tag">'   for t in missing_info] +
            [f'##FORMAT=<ID={t},Number=.,Type=String,Description="Undefined FORMAT tag">' for t in missing_fmt]
        )
        print(f"Fixing undefined header tags: INFO={missing_info} FORMAT={missing_fmt}", file=sys.stderr)
        with open('fixed_header.txt', 'w') as fh:
            fh.write(header.replace('#CHROM', extra + '\n#CHROM', 1))
        subprocess.run(
            ["bcftools", "reheader", "-h", "fixed_header.txt", vcf, "-o", "input_for_view.vcf.gz"],
            check=True
        )
        with open('vcf_input.txt', 'w') as fh:
            fh.write('input_for_view.vcf.gz')
    else:
        with open('vcf_input.txt', 'w') as fh:
            fh.write(vcf)

    CODE

    VCF_INPUT=$(cat vcf_input.txt)
    if [ -s excluded_samples.txt ]; then
      bcftools view -S keep_samples.txt "${VCF_INPUT}" -O z -o ~{collection_name}_filtered.vcf.gz
    else
      cp ~{vcf} ~{collection_name}_filtered.vcf.gz
    fi

  >>>
  output {
    File filtered_vcf = "~{collection_name}_filtered.vcf.gz"
    Array[String] excluded_samples = read_lines("excluded_samples.txt")
  }
  runtime {
    docker: "marcoteix/gemstone-utils:1.0.0"
    memory: memory + " GB"
    cpu: 1
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
  }
}
