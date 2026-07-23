version 1.0

task merge_multivcfs {
  input {
    Array[File] vcfs
    String collection_name = "variants"
    String? filters
    Int memory = 8
    Int disk_size = 16
  }
  command <<<

    mkdir ./vcfs

    # Iterate over VCFs
    vcfs=( ~{sep=' ' vcfs} )

    # Make a file with paths to VCF files
    touch filelist.txt

    for i in "${!vcfs[@]}"; do

        vcf="${vcfs[i]}"

        echo "Indexing vcf" $vcf"..."

        # Index
        bcftools index $vcf

        # Write to file of files
        echo $vcf >> filelist.txt

    done

    # Merge VCFs
    echo "Merging vcfs..."

    bcftools merge \
        -l filelist.txt \
        -o ~{collection_name}_merged.vcf.gz \
        -O z \
        ~{'-f \"' + filters + '\"'} \
        --force-samples \
        --force-single

  >>>
  output {
    File merged_vcf = "~{collection_name}_merged.vcf.gz"
  }
  runtime {
    docker: "marcoteix/gemstone-utils:1.0.0"
    memory: memory + " GB"
    cpu: 1
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 2
  }
}