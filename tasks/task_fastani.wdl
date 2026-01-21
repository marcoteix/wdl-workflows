version 1.0

task fastani {
  input {
    File reference
    File query
    # FastANI options
    Int kmer_size = 16
    Int fragment_length = 3000
    Float min_fraction = 0.2
    Float max_ratio_difference = 10.0
    # Compute options
    Int cpu = 1
    Int memory = 16
    Int disk_size = 50
    String docker = "staphb/fastani:1.34-rgdv2"
  }
  command <<<

    # Get the fastANI version
    fastANI --version > VERSION.txt

    # Split input files into multiple files, one per contig
    mkdir reference_fastas
    mkdir query_fastas

    awk '/^>/ {split(substr($0,2),a," "); OUT="reference_fastas/" a[1] ".fa"; print $0 >OUT; next} OUT{print >OUT}' ~{reference}
    awk '/^>/ {split(substr($0,2),a," "); OUT="query_fastas/" a[1] ".fa"; print $0 >OUT; next} OUT{print >OUT}' ~{query}

    # Write a file of files for the reference and query
    ls -d reference_fastas/*.fa > reference_fof.txt 
    ls -d query_fastas/*.fa > query_fof.txt 

    echo "Reference files:"
    cat reference_fof.txt

    echo "Query files:"
    cat query_fof.txt

    # Run fastANI
    fastANI \
        --refList reference_fof.txt \
        --queryList query_fof.txt \
        --kmer ~{kmer_size} \
        --threads ~{cpu} \
        --fragLen ~{fragment_length} \
        --minFraction ~{min_fraction} \
        --maxRatioDiff ~{max_ratio_difference} \
        --output "fastani_results.tsv"

  >>>
  output {
    String fastani_version = read_string("VERSION.txt")
    File fastani_results = "fastani_results.tsv"
  }
  runtime {
    docker: docker
    memory: "~{memory} GB"
    cpu: cpu
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    maxRetries: 0
    preemptible: 0
  }
}