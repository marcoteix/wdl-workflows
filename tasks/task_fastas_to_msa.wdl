version 1.0

task fastas_to_msa {
  input {
    Array[File] fastas
    File reference_fasta
    String collection_name
    Float max_missing_pct = 20.0
    String docker = "marcoteix/cleansweep:refs-heads-main"
    Int memory = 16
    Int disk_size = 64
  }
  command <<<

    touch excluded_samples.txt

    # Write input FASTA paths one per line for Python consumption
    fastas=( ~{sep=' ' fastas} )
    printf '%s\n' "${fastas[@]}" > fasta_paths.txt

    python3 << 'CODE'
import gzip
import string
import sys

max_missing_pct = ~{max_missing_pct}
reference_fasta  = "~{reference_fasta}"
collection_name  = "~{collection_name}"

# The MSA may only contain A, C, G, T, N, and -. Any other character (IUPAC
# ambiguity codes such as R/Y/S/W/K/M/B/D/H/V, or anything unexpected) is
# collapsed to N. Sequences are uppercased in iter_fasta before this table is
# applied, so only the uppercase letters need to be covered.
_SANITIZE_TABLE = {ord(c): ord('N') for c in string.ascii_uppercase if c not in "ACGTN"}

def sanitize_seq(seq):
    """Replace IUPAC ambiguity codes (and any other non-ACGTN- character) with N."""
    return seq.translate(_SANITIZE_TABLE)

def iter_fasta(path):
    """Yield (name, sequence) one sequence at a time without buffering the file."""
    name, seq_lines = None, []
    opener = gzip.open if path.endswith('.gz') else open
    with opener(path, 'rt') as fh:
        for line in fh:
            line = line.rstrip('\n')
            if line.startswith('>'):
                if name is not None:
                    yield name, sanitize_seq(''.join(seq_lines).upper())
                name = line[1:].split()[0]
                seq_lines = []
            elif line:
                seq_lines.append(line)
    if name is not None:
        yield name, sanitize_seq(''.join(seq_lines).upper())

def write_seq(fh, name, seq, line_width=60):
    fh.write(f">{name}\n")
    for i in range(0, len(seq), line_width):
        fh.write(seq[i:i + line_width] + '\n')

# Load reference to establish expected length; it is always written first
ref_iter = iter_fasta(reference_fasta)
try:
    ref_name, ref_seq = next(ref_iter)
except StopIteration:
    print("ERROR: Reference FASTA is empty.", file=sys.stderr)
    sys.exit(1)
expected_len = len(ref_seq)

with open("fasta_paths.txt") as fh:
    fasta_paths = [line.strip() for line in fh if line.strip()]

kept = excluded = 0

with open(f"{collection_name}.msa.fasta", "w") as out_fh, \
     open("excluded_samples.txt", "w") as excl_fh:

    write_seq(out_fh, ref_name, ref_seq)
    ref_seq = None  # release reference sequence memory

    for path in fasta_paths:
        for name, seq in iter_fasta(path):
            if len(seq) != expected_len:
                print(
                    f"ERROR: Sequence '{name}' in {path} has length {len(seq)}, "
                    f"but reference '{ref_name}' has length {expected_len}.",
                    file=sys.stderr,
                )
                sys.exit(1)
            n_pct = seq.count('N') / expected_len * 100
            if n_pct > max_missing_pct:
                print(
                    f"Excluding '{name}': {n_pct:.2f}% missing sites "
                    f"(threshold {max_missing_pct}%).",
                    file=sys.stderr,
                )
                excl_fh.write(name + '\n')
                excluded += 1
            else:
                write_seq(out_fh, name, seq)
                kept += 1

print(
    f"MSA written: 1 reference + {kept} samples, {expected_len} bp. "
    f"{excluded} sample(s) excluded.",
    file=sys.stderr,
)
CODE

  >>>
  output {
    File msa = "~{collection_name}.msa.fasta"
    Array[String] excluded_samples = read_lines("excluded_samples.txt")
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
