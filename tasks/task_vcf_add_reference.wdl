version 1.0

task vcf_add_reference {
    # Adds genotype information for the reference genome to a VCF file (all sites REF).
  input {
    File merged_vcf 
    String collection_name
    String docker = "marcoteix/cleansweep:main"
  }
  command <<<

    # Uncompress VCF
    bcftools view \
        -O v \
        -o merged_vcf.vcf \
        ~{merged_vcf}

    python3 <<CODE
    import pandas as pd

    with open("merged_vcf.vcf") as infile:
        with open("~{collection_name}.reference.vcf", "w") as outfile:
            for line in infile.readlines():
                if not line.startswith("#"):
                    line = line.removesuffix("\n") + "\t0\n"
                elif not line.startswith("##"):
                    line = line.removesuffix("\n") + "\tReference\n"
                outfile.write(line)
    CODE

    bcftools view \
        -O z \
        -o ~{collection_name}.reference.vcf.gz \
        ~{collection_name}.reference.vcf
  >>>
  output {
    File vcf_out = "~{collection_name}.reference.vcf.gz"
  }
  runtime {
    docker: docker
    memory: "8 GB"
    cpu: 1
    disks:  "local-disk 10 SSD"
    disk: "32 GB" # TES
    preemptible: 0
    maxRetries: 1
  }
}