version 1.0

task filter_msa_sites {
  input {
    File msa
    String collection_name
    Int memory = 8
    Int disk_size = 16
  }
  command <<<
    python3 << 'CODE'
    msa_path = "~{msa}"
    out_path = "~{collection_name}_filtered.fasta"

    # Parse FASTA
    sequences = {}
    order = []
    current_name = None
    with open(msa_path) as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('>'):
                current_name = line[1:]
                sequences[current_name] = []
                order.append(current_name)
            elif current_name is not None:
                sequences[current_name].extend(list(line))

    if not order:
        raise RuntimeError("No sequences found in FASTA file.")

    aln_len = len(sequences[order[0]])
    unknown = {'N', 'n', '-'}

    excluded = 0
    keep_cols = []
    for i in range(aln_len):
        if any(sequences[name][i] in unknown for name in order):
            excluded += 1
        else:
            keep_cols.append(i)

    with open(out_path, 'w') as f:
        for name in order:
            seq = ''.join(sequences[name][i] for i in keep_cols)
            f.write(f'>{name}\n{seq}\n')

    pct = excluded / aln_len * 100 if aln_len > 0 else 0.0
    print(f"Total sites: {aln_len}, excluded: {excluded} ({pct:.2f}%)")

    with open("excluded_sites_count.txt", "w") as f:
        f.write(str(excluded))
    with open("excluded_sites_pct.txt", "w") as f:
        f.write(f"{pct:.2f}")

    CODE
  >>>
  output {
    File filtered_msa = "~{collection_name}_filtered.fasta"
    Int excluded_sites_count = read_int("excluded_sites_count.txt")
    Float excluded_sites_pct = read_float("excluded_sites_pct.txt")
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
