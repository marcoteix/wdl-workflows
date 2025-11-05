version 1.0

task plasmer {
  # Annotates plasmid contigs with Plasmer
  input {
    File assembly_fasta
    File plasmer_database 
    String samplename
    Int min_length = 500
    Int length = 0
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/plasmer:23.04.20"
    Int disk_size = 128
    Int memory = 16
    Int cpu = 4
  }
  command <<<

    # Extract Plasmer databases
    mkdir plasmer_database
    tar -xvf ~{plasmer_database} -C plasmer_database

    # Get Plasmer version
    $PLASMER --version | cut -d" " -f2 | tee VERSION

    # Run Plasmer
    $PLASMER \
        --genome ~{assembly_fasta} \
        --prefix ~{samplename} \
        --db plasmer_database \
        --threads ~{cpu} \
        --minimum_length ~{min_length} \
        --length ~{length} \
        --outpath ~{samplename}

  >>>
  output {
    File plasmer_probabilities = "~{samplename}/results/~{samplename}.plasmer.predProb.tsv"
    File plasmer_classes = "~{samplename}/results/~{samplename}.plasmer.predClass.tsv"
    File plasmer_plasmid_taxa = "~{samplename}/results/~{samplename}.plasmer.predPlasmids.taxon"
    File plasmer_plasmid_fasta = "~{samplename}/results/~{samplename}.plasmer.predPlasmids.fa"
    String plasmer_version = read_string("VERSION")
    String plasmer_docker = "~{docker}"
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: cpu
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    maxRetries: 1
  }
}