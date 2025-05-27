version 1.0

task cleansweep_collection {
    input {
        Array[File] vcfs
        Array[String] samplenames
        String collection_name = "variants"
        Float min_ani = 0.998
        String docker = "marcoteix/cleansweep:main"
        Int memory = 8
        Int disk_size = 32
    }
    command <<<

        # Rename VCFs
        names=( ~{sep=' ' samplenames} )
        vcfs=( ~{sep=' ' vcfs} )

        mkdir vcfs

        for i in "${!names[@]}"; do

            name="${names[i]}"
            vcf="${vcfs[i]}"
            bcftools view -o vcfs/$name.vcf $vcf
        
        done

        # Run cleansweep collection
        echo "Merging VCFs with cleansweep collection..."

        mkdir cleansweep_tmp

        cleansweep collection \
            -o ~{collection_name}.merged.vcf \
            --min-ani ~{min_ani} \
            --tmp-dir cleansweep_tmp \
            vcfs/*.vcf

        echo "Compressing with bcftools view..."

        bcftools view \
            -o ~{collection_name}.merged.vcf.gz \
            -O z \
            ~{collection_name}.merged.vcf

        echo "Done!"

    >>>
    output {
        File merged_vcf = "~{collection_name}.merged.vcf.gz"
    }
    runtime {
        docker: docker
        memory: memory + " GB"
        cpu: 1
        disks:  "local-disk " + disk_size + " SSD"
        disk: disk_size + " GB"
        preemptible: 0
    }
}