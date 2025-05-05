version 1.0

task msweep {
  input {
    File alignment_1
    File alignment_2
    File clustering
    String samplename
    String docker = "quay.io/biocontainers/msweep:2.2.1--h503566f_1"
    Int cpu = 4
    Int memory = 16
    Int disk_size = 64
  }
  command <<<

    echo "Estimating abundances with mSWEEP..."
    mSWEEP \
        --themisto-1 ~{alignment_1} \
        --themisto-2 ~{alignment_2} \
        -i ~{clustering} \
        -o ~{samplename} \
        -t ~{cpu} \
        --write-probs

    # Find output files
    #printf "%s\n" ~{samplename}/msweep_*_abundances.txt > ABUNDANCES.txt
    #printf "%s\n" ~{samplename}/msweep_*_probs.tsv > PROBABILITIES.txt

    echo Done!

  >>>
  output {
    File msweep_abundances = "~{samplename}_abundances.txt"
    File msweep_probabilities = "~{samplename}_probs.tsv"
    String msweep_docker = "~{docker}"
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