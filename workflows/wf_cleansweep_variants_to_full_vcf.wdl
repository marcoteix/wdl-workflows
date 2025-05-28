version 1.0

import "../tasks/task_cleansweep_variants_to_full_vcf.wdl" as variants_to_full_task

workflow cleansweep_variants_to_full_vcf {
    # Given an output VCF file from CleanSweep with only the variant sites and 
    # the full VCF file used as input for CleanSweep, creates a CleanSweep 
    # output VCF containing all sites in the reference.
    input {
        File cleansweep_output_vcf 
        File cleansweep_input_vcf
        String samplename
        Int min_dp = 0
        String docker = "marcoteix/cleansweep:main"
    }
    call variants_to_full_task.cleansweep_variants_to_full_vcf {
        input:
            cleansweep_output_vcf = cleansweep_output_vcf,
            cleansweep_input_vcf = cleansweep_input_vcf,
            samplename = samplename,
            min_dp = min_dp,
            docker = docker
    }
    output {
        File cleansweep_full_vcf = cleansweep_variants_to_full_vcf.vcf_out
    }
}