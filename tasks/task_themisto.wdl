version 1.0

task themisto {
  input {
    Array[File] references
    Array[String] reference_names
    File reads1
    File reads2
    String samplename
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/themisto:3.2.2"
    Int kmer_size = 31
    Int cpu = 4
    Int memory = 32
    Int disk_size = 64
  }
  command <<<

    echo "Creating a file with paths to the reference FASTAs..."

    # File with a list of references
    references=(~{sep=' ' references})
    printf "%s\n" "${references[@]}" > fof.txt

    mkdir -p themisto_tmp
    mkdir -p ~{samplename}

    echo "Building the themisto index..."
    themisto build \
        -k ~{kmer_size} \
        -i fof.txt \
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
        --sort-output-lines \
        --gzip-output

    echo "Aligning reverse reads with Themisto..."
    themisto pseudoalign \
        -q ~{reads2} \
        -o ~{samplename}/alignment_2.aln \
        -i ~{samplename}_index \
        --temp-dir themisto_tmp \
        --rc \
        --n-threads ~{cpu} \
        --sort-output-lines \
        --gzip-output

    echo "Adding ~{samplename}_index to a tar file..."
    tar -czf ~{samplename}_index.tar.gz ~{samplename}_index.*

    echo "Creating a clustering file..."
    clusters=(~{sep=' ' reference_names})
    printf "%s\n" "${clusters[@]}" > ~{samplename}_clustering.txt

    echo Done!

  >>>
  output {
    File themisto_alignment1 = "~{samplename}/alignment_1.aln.gz"
    File themisto_alignment2 = "~{samplename}/alignment_2.aln.gz"
    File themisto_index = "~{samplename}_index.tar.gz"
    File clustering = "~{samplename}_clustering.txt"
    String themisto_docker = "~{docker}"
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

task themisto_index {
  input {
    Array[File] references
    Array[String] reference_names
    String samplename
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/themisto:3.2.2"
    Int kmer_size = 31
    Int memory = 32
    Int disk_size = 128
    Int cpu = 4
  }
  command <<<

    echo "Creating a file with paths to the reference FASTAs..."

    # File with a list of references
    references=(~{sep=' ' references})
    printf "%s\n" "${references[@]}" > fof.txt

    mkdir -p themisto_tmp
    mkdir -p ~{samplename}

    echo "Building the themisto index..."
    themisto build \
        -k ~{kmer_size} \
        -i fof.txt \
        -o ~{samplename}_index \
        --temp-dir themisto_tmp \
        -t ~{cpu}

    echo "Adding ~{samplename}_index to a tar file..."
    tar -czf ~{samplename}_index.tar.gz ~{samplename}_index.*

    echo "Creating a clustering file..."
    clusters=(~{sep=' ' reference_names})
    printf "%s\n" "${clusters[@]}" > ~{samplename}_clustering.txt

    echo Done!

  >>>
  output {
    File themisto_index = "~{samplename}_index.tar.gz"
    File clustering = "~{samplename}_clustering.txt"
    String themisto_docker = "~{docker}"
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

task themisto_align {
  input {
    File themisto_index
    File reads1
    File reads2
    String samplename
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/themisto:3.2.2"
    Int cpu = 4
    Int memory = 32
    Int disk_size = 64
  }
  command <<<

    echo "Creating a file with paths to the reference FASTAs..."

    # Untar index
    tar -xzfv ~{themisto_index} -C ./index

    # Rename index files so we get a known prefix
    mv index/*.tdbg themisto_index.tdbg
    mv index/*.tcolors themisto_index.tcolors

    mkdir -p themisto_tmp
    mkdir -p ~{samplename}

    echo "Aligning forward reads with Themisto..."
    themisto pseudoalign \
        -q ~{reads1} \
        -o ~{samplename}/alignment_1.aln \
        -i themisto_index \
        --temp-dir themisto_tmp \
        --rc \
        --n-threads ~{cpu} \
        --sort-output-lines \
        --gzip-output

    echo "Aligning reverse reads with Themisto..."
    themisto pseudoalign \
        -q ~{reads2} \
        -o ~{samplename}/alignment_2.aln \
        -i themisto_index \
        --temp-dir themisto_tmp \
        --rc \
        --n-threads ~{cpu} \
        --sort-output-lines \
        --gzip-output

    echo Done!

  >>>
  output {
    File themisto_alignment1 = "~{samplename}/alignment_1.aln.gz"
    File themisto_alignment2 = "~{samplename}/alignment_2.aln.gz"
    String themisto_docker = "~{docker}"
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