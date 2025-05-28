version 1.0

task merge_vcfs {
  input {
    Array[String] samplenames
    Array[File] vcfs
    String collection_name = "variants"
    String filters = "PASS,."
    String? include
    Int memory = 8
    Int disk_size = 16
  }
  command <<<

    mkdir ./vcfs

    # Iterate over the sample names and VCF files simultaneously.
    # Filter VCFs
    names=( ~{sep=' ' samplenames} )
    vcfs=( ~{sep=' ' vcfs} )

    # Keep track of sample names so we can change the sample names in the merged VCF
    touch samplenames.txt
    # Make a file with paths to VCF files
    touch filelist.txt

    for i in "${!names[@]}"; do

        name="${names[i]}"
        vcf="${vcfs[i]}"

        echo "Filtering and indexing $vcf..."

        # Filter VCFs
        bcftools view \
            -f ~{filters} \
            ~{'-i \"' + include + '\"'} \
            -o ./vcfs/$name.pass.vcf.gz \
            -O b

        # Index
        bcftools index ./vcfs/$name.pass.vcf.gz

        echo $name >> samplenames.txt
        echo $(pwd)/vcfs/$name.pass.vcf.gz >> filelist.txt

    done

    # Merge VCFs
    echo "Merging vcfs..."

    bcftools merge \
        -l filelist.txt \
        -o ~{collection_name}.merged.vcf.gz \
        -O b \
        -f ~{filters} \
        --force-samples

    # Change sample names in the merged VCF
    echo "Replacing sample names in the merged VCF..."

    bcftools view ~{collection_name}.merged.vcf.gz | \
        bcftools reheader -s samplenames.txt -o ~{collection_name}.merged.vcf

    bcftools view \
        -o ~{collection_name}.merged.vcf.gz \
        -O z \
        ~{collection_name}.merged.vcf

  >>>
  output {
    File merged_vcf = "~{collection_name}.merged.vcf.gz"
    String bcftools_version = read_string("bcftools_version.txt")
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