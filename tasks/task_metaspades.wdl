version 1.0

task metaspades {
  # Assembles paired-end reads with metaSPAdes and packages the files
  # required by PlasMAAG (contigs.fasta, assembly_graph_after_simplification.gfa,
  # contigs.paths) into a tar.gz archive.
  input {
    File read1
    File read2
    String samplename
    String docker = "us-docker.pkg.dev/general-theiagen/staphb/spades:4.2.0"
    Int cpu = 8
    Int memory = 32
    Int disk_size = 100
  }
  command <<<
    set -euo pipefail

    metaspades.py --version 2>&1 | head -1 | tee VERSION

    metaspades.py \
        -1 ~{read1} \
        -2 ~{read2} \
        -o spades_out \
        -t ~{cpu} \
        -m ~{memory}

    mkdir -p ~{samplename}_assembly
    cp spades_out/contigs.fasta ~{samplename}_assembly/
    cp spades_out/assembly_graph_after_simplification.gfa ~{samplename}_assembly/
    cp spades_out/contigs.paths ~{samplename}_assembly/

    tar -czf ~{samplename}_assembly.tar.gz ~{samplename}_assembly/
  >>>
  output {
    File assembly_archive = "~{samplename}_assembly.tar.gz"
    String metaspades_version = read_string("VERSION")
    String metaspades_docker = "~{docker}"
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: cpu
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
    maxRetries: 1
  }
}
