version 1.0

task multivcf_to_msa {
  input {
    File vcf
    String collection_name = "variants"
    Int memory = 8
    Int disk_size = 16
  }
  command <<<

    echo "Generating MSA..."

    python /tmp/scripts/vcf2phylip.py \
        -i ~{vcf} \
        --output-folder "msa" \
        --output-prefix ~{collection_name} \
        -f -p -m 1

    # Rename output file
    mv "msa/~{collection_name}.min1.fasta" "msa/~{collection_name}.fasta"

    # Get versions
    python /tmp/scripts/vcf2phylip.py --version > vcf2phylip_version.txt

  >>>
  output {
    File msa = "msa/~{collection_name}.fasta"
    String vcf2phylip_version = read_string("vcf2phylip_version.txt")
  }
  runtime {
    docker: "marcoteix/gemstone-utils:1.0.0"
    memory: memory + " GB"
    cpu: 1
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
  }
}