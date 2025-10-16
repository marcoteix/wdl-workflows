version 1.0

task freebayes {
  input {
    File reference
    File bam
    File bai
    String samplename
    Int min_observations = 2 # Minimum haploids needed for variant calling
    Float min_allele_fraction = 0.05
    Int ploidy = 1
    String docker = "staphb/freebayes:1.3.10"
    String extra_options = ""
    Int cpu = 2
    Int memory = 32
    Int disk_size = 100
  }
  command <<<
    # version capture
    freebayes --version | cut -d' ' -f3 | tee VERSION

    # Run FreeBayes
    freebayes \
      -f ~{reference} \
      ~{bam} \
      --report-monomorphic \
      --ploidy ~{ploidy} \
      --min-alternate-fraction ~{min_allele_fraction} \
      --min-alternate-count ~{min_observations} \
      ~{extra_options} > ~{samplename}.vcf

  >>>
  output {
    File vcf = "~{samplename}.vcf"
    String freebayes_version = read_string("VERSION")
    String freebayes_docker = "~{docker}"
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