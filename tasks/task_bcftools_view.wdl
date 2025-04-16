version 1.0

task bcftools_view {
  input {
    File vcf
    String samplename
    String docker = "marcoteix/cleansweep:0.2"
    String output_type = "v"
    String output_extension = "vcf"
    String query = ""
    Int memory = 4
  }
  command <<<

    mkdir -p ~{samplename}

    bcftools view  \
        -o ~{samplename}/~{samplename}.variants.~{output_extension} \
        -O ~{output_type} \
        ~{query} \
        ~{vcf}

  >>>
  output {
    File output_vcf = "~{samplename}/~{samplename}.variants.~{output_extension}"
  }
  runtime {
    docker: docker
    memory: "~{memory} GB"
    cpu: 1
    disks:  "local-disk 16" + " SSD"
    disk: "16 GB"
    preemptible: 0
  }
}