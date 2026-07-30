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

def resolve_calls(calls):
    """Determine the IUPAC nucleotide for a list of calls at one position."""
    bases = []
    for ref, alt, depth, gt in calls:
        if depth is not None and depth < min_dp:
            return "N"
        for allele in gt.replace("|", "/").split("/"):
            if allele == ".":
                return "N"
            elif allele == "0":
                bases.append(ref)
            elif allele == "1":
                bases.append(alt)
            else:
                return "N"
    if not bases:
        return "N"
    return IUPAC_CODES.get("".join(sorted(set(bases))), "N")

# First pass: find the maximum position without keeping any records in memory.
# positions.tsv is position-sorted, so this is just a scan of the first column.
max_pos = 0
with open("positions.tsv") as f:
    for line in f:
        col = line.split("\t", 1)
        try:
            p = int(col[0])
            if p > max_pos:
                max_pos = p
        except (ValueError, IndexError):
            pass

if max_pos == 0:
    print("WARNING: No positions found in VCF", file=sys.stderr)
    with open(f"{sequence_name}.fasta", "w") as f:
        f.write(f">{sequence_name}\n\n")
    sys.exit(0)

seq = bytearray(b"N" * max_pos)

# Second pass: stream line by line, accumulating calls only for the current
# position (multi-allelic sites appear on consecutive rows after bcftools norm).
with open("positions.tsv") as f:
    prev_pos = None
    calls = []
    for line in f:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 5:
            continue
        try:
            pos = int(parts[0])
        except ValueError:
            continue
        ref, alt, dp_str, gt = parts[1], parts[2], parts[3], parts[4]
        try:
            depth = int(dp_str)
        except ValueError:
            depth = None  # DP absent — skip depth filter for this call

        if prev_pos is not None and pos != prev_pos:
            seq[prev_pos - 1] = ord(resolve_calls(calls))
            calls = []
        calls.append((ref, alt, depth, gt))
        prev_pos = pos

    if calls and prev_pos is not None:
        seq[prev_pos - 1] = ord(resolve_calls(calls))

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
    preemptible: 0
  }
}
