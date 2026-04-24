version 1.0

task mmseqs2_assembly_search {
  # Filters assembly contigs by length and runs an mmseqs2 easy-search against
  # a tar-archived reference database. Output is a TSV with header including
  # query/reference coverage and other useful alignment statistics. Top hits
  # per query are limited via --max-seqs.
  input {
    File assembly
    File reference
    String reference_name
    String samplename
    Int min_contig_length = 1000
    Int max_hits_per_contig = 5
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/mmseqs2:8cc5ce367b5638c4306c2d7cfc652dd099a4643f"
    Int cpu = 4
    Int memory = 16
    Int disk_size = 50
  }
  command <<<
    set -euo pipefail

    # Filter assembly to contigs >= min_contig_length and count survivors.
    awk -v min_len=~{min_contig_length} '
      BEGIN { name=""; seq="" }
      /^>/ {
        if (name != "" && length(seq) >= min_len) { print name; print seq }
        name=$0; seq=""; next
      }
      { seq = seq $0 }
      END {
        if (name != "" && length(seq) >= min_len) { print name; print seq }
      }
    ' ~{assembly} > filtered.fasta

    grep -c "^>" filtered.fasta > filtered_contig_count.txt || echo 0 > filtered_contig_count.txt

    tar -xzvf ~{reference}

    mmseqs easy-search \
        filtered.fasta \
        db/~{reference_name}/~{reference_name} \
        ~{samplename}.mmseqs2.tsv \
        tmp \
        --search-type 3 \
        --sort-results 1 \
        --format-mode 4 \
        --format-output "query,target,pident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits,qlen,tlen,qcov,tcov" \
        --max-seqs ~{max_hits_per_contig} \
        --threads ~{cpu}
  >>>
  output {
    File mmseqs2_alignment = "~{samplename}.mmseqs2.tsv"
    Int filtered_contig_count = read_int("filtered_contig_count.txt")
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: cpu
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
    maxRetries: 0
  }
}
