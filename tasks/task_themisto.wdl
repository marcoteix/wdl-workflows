version 1.0

task themisto {
  input {
    File reference
    File reads1
    File reads2
    String samplename
    String docker = "marcoteix/themisto:3.2.2"
    Int kmer_size = 31
    Int cpu = 4
    Int memory = 32
    Int disk_size = 64
  }
  command <<<
    # version capture
    themisto --version > VERSION.TXT

    echo "Building the themisto index..."
    themisto build \
        -k ~{kmer_size} \
        -i ~{reference} \
        -o ~{samplename}_index \
        --temp-dir themisto_tmp

    echo "Aligning forward reads with Themisto..."
    themisto pseudoalign \
        -q ~{reads1} \
        -o ~{samplename}/alignment_1.aln \
        -i ~{samplename}_index \
        --temp-dir themisto_tmp \
        --rc \
        --n-threads ~{cpu} \
        --sort-output \
        --gzip-output

    echo "Aligning reverse reads with Themisto..."
    themisto pseudoalign \
        -q ~{reads2} \
        -o ~{samplename}/alignment_2.aln \
        -i ~{samplename}_index \
        --temp-dir themisto_tmp \
        --rc \
        --n-threads ~{cpu} \
        --sort-output \
        --gzip-output

  >>>
  output {
    File themisto_alignment1 = "~{samplename}/alignment_1.aln"
    File themisto_alignment2 = "~{samplename}/alignment_2.aln"
    String themisto_version = read_string("VERSION.TXT")
    String themisto_docker = "~{docker}"
  }
  runtime {
    docker: "~{docker}"
    memory: "~{memory} GB"
    cpu: cpu
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    maxRetries: 3
  }
}