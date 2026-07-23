version 1.0

task cleansweep_collection {
    input {
        Array[File] vcfs
        Array[String] samplenames
        String collection_name = "variants"
        Float alpha = 10
        Int min_coverage = 10
        Boolean exclude = false
        String docker = "marcoteix/cleansweep:heads-main"
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

        # Inject missing INFO header declarations (PILON, LowCov) that bcftools merge
        # requires but Pilon-generated VCFs often omit from their headers.
        printf '##INFO=<ID=PILON,Number=.,Type=String,Description="Pilon variant annotation">\n##INFO=<ID=LowCov,Number=0,Type=Flag,Description="Low coverage region">\n' > header_fix.txt
        for vcf in vcfs/*.vcf; do
            bcftools annotate -h header_fix.txt -o "${vcf}.tmp" "$vcf" && mv "${vcf}.tmp" "$vcf"
        done

        # Run cleansweep collection
        echo "Merging VCFs with cleansweep collection..."

        mkdir cleansweep_tmp
        # Create a file listing excluded samples, even if exclude == False (file 
        # will be empty and the excluded_samples output array will be empty)
        touch "excluded.txt"

        cleansweep collection \
            -o ~{collection_name}.merged.vcf \
            --alpha ~{alpha} \
            --min-coverage ~{min_coverage} \
            --tmp-dir cleansweep_tmp \
            ~{true="--exclude --exclude-log excluded.txt" false="" exclude} \
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
        Array[String] excluded_samples = read_lines("excluded.txt")
    }
    runtime {
        docker: docker
        memory: memory + " GB"
        cpu: 1
        disks:  "local-disk " + disk_size + " SSD"
        disk: disk_size + " GB"
        preemptible: 2
    }
}