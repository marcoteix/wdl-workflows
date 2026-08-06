version 1.0

task cleansweep_collection {
    input {
        Array[File] vcfs
        Array[String] samplenames
        File? reference_fasta
        String collection_name = "variants"
        Float alpha = 10
        Int min_coverage = 10
        Boolean exclude = false
        String docker = "marcoteix/cleansweep:refs-heads-main"
        Int memory = 32
        Int disk_size = 128
        Int cpu = 8
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

        # Convert CleanSweep VCFs to an MSA
        cleansweep collection \
            -o ~{collection_name}_msa.fa \
            ~{"--reference " + reference_fasta} \
            --alpha ~{alpha} \
            --min-coverage ~{min_coverage} \
            --n-threads ~{cpu} \
            ~{true="--exclude --exclude-log excluded.txt" false="" exclude} \
            vcfs/*.vcf

        echo "Done!"

    >>>
    output {
        File msa_fasta = "~{collection_name}_msa.fa"
        Array[String] excluded_samples = read_lines("excluded.txt")
    }
    runtime {
        docker: docker
        memory: memory + " GB"
        cpu: cpu
        disks:  "local-disk " + disk_size + " SSD"
        disk: disk_size + " GB"
        preemptible: 0
    }
}