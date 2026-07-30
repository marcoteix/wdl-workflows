version 1.0

task vcf_to_fasta {
  input {
    File vcf
    String sequence_name
    Int min_dp = 10
    String docker = "marcoteix/cleansweep:heads-main"
    Int memory = 16
    Int disk_size = 64
  }
  command <<<

    # Split multi-allelic sites, strip indels, extract needed columns
    bcftools norm -m - ~{vcf} | \
        bcftools view -V indels | \
        bcftools query -f '%POS\t%REF\t%ALT\t%INFO/DP\t[%GT]\n' > positions.tsv

    python3 << 'CODE'
import sys

IUPAC_CODES = {
    "A": "A", "C": "C", "G": "G", "T": "T", "N": "N",
    "AG": "R", "CT": "Y", "CG": "S", "AT": "W", "GT": "K", "AC": "M",
    "CGT": "B", "AGT": "D", "ACT": "H", "ACG": "V",
    ".": ".", "-": "-",
}

sequence_name = "~{sequence_name}"
min_dp = ~{min_dp}

# Group calls by position; a position may appear multiple times after norm splits
# multi-allelic sites into separate rows.
positions = {}
with open("positions.tsv") as f:
    for line in f:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 5:
            continue
        pos, ref, alt, dp_str, gt = parts[0], parts[1], parts[2], parts[3], parts[4]
        pos = int(pos)
        try:
            depth = int(dp_str)
        except ValueError:
            depth = None  # DP absent — skip depth filter for this call
        positions.setdefault(pos, []).append((ref, alt, depth, gt))

if not positions:
    print("WARNING: No positions found in VCF", file=sys.stderr)
    with open(f"{sequence_name}.fasta", "w") as f:
        f.write(f">{sequence_name}\n\n")
    sys.exit(0)

max_pos = max(positions.keys())
seq = bytearray(b"N" * max_pos)

for pos, calls in positions.items():
    bases = []
    use_n = False
    for ref, alt, depth, gt in calls:
        if depth is not None and depth < min_dp:
            use_n = True
            break
        # Normalize phased/unphased diploid (0|1 → [0, 1]) and haploid (1 → [1])
        alleles = gt.replace("|", "/").split("/")
        for allele in alleles:
            if allele == ".":
                use_n = True
                break
            elif allele == "0":
                bases.append(ref)
            elif allele == "1":
                bases.append(alt)
            else:
                use_n = True
                break
        if use_n:
            break

    if use_n or not bases:
        nuc = "N"
    else:
        key = "".join(sorted(set(bases)))
        nuc = IUPAC_CODES.get(key, "N")

    seq[pos - 1] = ord(nuc)

sequence = seq.decode("ascii")
with open(f"{sequence_name}.fasta", "w") as f:
    f.write(f">{sequence_name}\n")
    for i in range(0, len(sequence), 60):
        f.write(sequence[i:i + 60] + "\n")

print(f"Wrote {max_pos} bp FASTA to {sequence_name}.fasta", file=sys.stderr)
CODE

  >>>
  output {
    File fasta = "~{sequence_name}.fasta"
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: 1
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 1
  }
}
