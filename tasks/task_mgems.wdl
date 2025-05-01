version 1.0

task mgems {
  input {
    File reads_1
    File reads_2
    File themisto_index
    File alignment_1
    File alignment_2
    File msweep_probabilities
    File msweep_abundances
    File clustering
    String samplename
    String query = ""
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/mgems:1.3.3"
    Int cpu = 1
    Int memory = 16
    Int disk_size = 64
  }
  command <<<

    mkdir ~{samplename}

    # Untar themisto index
    tar -xvf ~{themisto_index} -C themisto_index

    mGEMS \
        -r ~{reads_1},~{reads_2} \
        -i ~{clustering} \
        --themisto-alns ~{alignment_1},~{alignment_2} \
        -o ~{samplename} \
        --probs ~{msweep_probabilities} \
        -a ~{msweep_abundances} \
        --index themisto_index

    # Find output files
    printf "%s\n" ~{samplename}/*.fastq.gz > BINS.txt
 
    echo Done!

  >>>
  output {
    Array[File] mgems_binned_reads = read_lines("BINS.txt")
    File mgems_query_reads_1 = "~{samplename}/~{query}_1.fastq.gz"
    File mgems_query_reads_2 = "~{samplename}/~{query}_2.fastq.gz"
    String mgems_docker = "~{docker}"
  }
  runtime {
    docker: "~{docker}"
    memory: "~{memory} GB"
    cpu: cpu
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    maxRetries: 1
  }
}