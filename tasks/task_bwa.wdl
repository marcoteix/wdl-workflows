version 1.0

# Adapted from Libuit, Kevin G., Emma L. Doughty, James R. Otieno, Frank Ambrosio, Curtis J. Kapsak, Emily A. Smith, 
# Sage M. Wright, et al. 2023. “Accelerating Bioinformatics Implementation in Public Health.” Microbial Genomics 9 
# (7). https://doi.org/10.1099/mgen.0.001051.

task bwa {
  input {
    File read1
    File? read2
    String samplename
    File? reference_genome
    Int cpu = 6
    Int disk_size = 100
    Int open = 6
    Int extend = 1
    Int clip = 5 
    Int unpaired = 9
    Int mismatch = 4
    Int memory = 8
  }
  command <<<
    # date and version control
    date | tee DATE
    echo "BWA $(bwa 2>&1 | grep Version )" | tee BWA_VERSION
    samtools --version | head -n1 | tee SAMTOOLS_VERSION

    # set reference genome
    if [[ ! -z "~{reference_genome}" ]]; then
      echo "User reference identified; ~{reference_genome} will be utilized for alignement"
      ref_genome="~{reference_genome}"
      bwa index "~{reference_genome}"
      # move to primer_schemes dir; bwa fails if reference file not in this location
    else
      ref_genome="/artic-ncov2019/primer_schemes/nCoV-2019/V3/nCoV-2019.reference.fasta"  
    fi

    # Map with BWA MEM
    echo "Running bwa mem -t ~{cpu} -O ~{open} -E ~{extend} -L ~{clip} -U ~{unpaired} -B ~{mismatch} ${ref_genome} ~{read1} ~{read2} | samtools sort | samtools view -F 4 -o ~{samplename}.sorted.bam "
    bwa mem \
    -t ~{cpu} \
    -O ~{open} \
    -E ~{extend} \
    -L ~{clip} \
    -U ~{unpaired} \
    -B ~{mismatch} \
    "${ref_genome}" \
    ~{read1} ~{read2} |\
    samtools sort | samtools view -F 4 -o ~{samplename}.sorted.bam

    if [[ ! -z "~{read2}" ]]; then
      echo "processing paired reads"
      samtools fastq -F4 -1 ~{samplename}_R1.fastq.gz -2 ~{samplename}_R2.fastq.gz ~{samplename}.sorted.bam
    else
      echo "processing single-end reads"
      samtools fastq -F4 ~{samplename}.sorted.bam | gzip > ~{samplename}_R1.fastq.gz
    fi


    # index BAMs
    samtools index ~{samplename}.sorted.bam
  >>>
  output {
    String bwa_version = read_string("BWA_VERSION")
    String sam_version = read_string("SAMTOOLS_VERSION")
    File sorted_bam = "${samplename}.sorted.bam"
    File sorted_bai = "${samplename}.sorted.bam.bai"
    File read1_aligned = "~{samplename}_R1.fastq.gz"
    File? read2_aligned = "~{samplename}_R2.fastq.gz"
  }
  runtime {
    docker: "us-docker.pkg.dev/general-theiagen/staphb/ivar:1.3.1-titan"
    memory: "~{memory} GB"
    cpu: cpu
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    #maxRetries: 3
  }
}