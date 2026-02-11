version 1.0

task mmseqs2_search {
  input {
    File query # Either a FASTA file or an MMseqs2 database
    File reference # An MMseqs2 database as a tar archive
    String samplename
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/mmseqs2:8cc5ce367b5638c4306c2d7cfc652dd099a4643f"
    Int search_type = 3 # Default is 3 (nucleotide)
    Int format_mode = 4 # Default is 4 (BLAST TSV with headers)
    String extra_options = ""
    Int cpu = 8
    Int memory = 32
    Int disk_size = 100
  }
  command <<<

    # Untar database
    mkdir reference
    tar -xzvf ~{reference}
    
    easy-search \
        ~{query} \
        db \
        ~{samplename}.mmseqs2.tsv \
        tmp \
        --search-type ~{search_type} \
        --sort-results 1 \
        --format-mode ~{format_mode} \
        --threads ~{cpu} ~{extra_options}

  >>>
  output {
    File mmseqs2_alignment = "~{samplename}.mmseqs2.tsv"
  }
  runtime {
    docker: "~{docker}"
    memory: "~{memory} GB"
    cpu: cpu
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    maxRetries: 0
  }
}