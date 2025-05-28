version 1.0

task cleansweep_variants_to_full_vcf {
    # Given an output VCF file from CleanSweep with only the variant sites and 
    # the full VCF file used as input for CleanSweep, creates a CleanSweep 
    # output VCF containing all sites in the reference.
    input {
        File cleansweep_output_vcf 
        File cleansweep_input_vcf
        String samplename
        Int min_dp = 0
        Int memory = 64
        String docker = "marcoteix/cleansweep:main"
    }
    command <<<

        python3 <<CODE

        from cleansweep import vcf 

        # Read header in the original VCF
        header = vcf.VCF("~{cleansweep_input_vcf}") \
            .get_header()

        vcf.write_full_vcf(
            vcf.VCF("~{cleansweep_output_vcf}").read(chrom=None),
            full_vcf = "~{cleansweep_input_vcf}",
            file = "~{samplename}.cleansweep.full.vcf",
            header = header,
            min_dp = ~{min_dp}
        )
        CODE

        # Compress output file
        bcftools view \
            -O z \
            -o ~{samplename}.cleansweep.full.vcf.gz \
            ~{samplename}.cleansweep.full.vcf
    >>>
    output {
        File vcf_out = "~{samplename}.cleansweep.full.vcf.gz"
    }
    runtime {
        docker: docker
        memory: memory + " GB"
        cpu: 1
        disks:  "local-disk 64 SSD"
        disk: "64 GB" # TES
        preemptible: 0
        maxRetries: 0
    }
}