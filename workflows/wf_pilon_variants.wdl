version 1.0

import "../tasks/task_bwa.wdl" as bwa_task
import "../tasks/task_pilon.wdl" as pilon_task
import "../tasks/task_bcftools_view.wdl" as bcftools_view_task

workflow pilon_variants {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Pipeline for variant calling with Pilon."
    }
    input {
        String samplename
        File reads_1
        File reads_2
        File reference_fasta
        Int alignment_cpu = 6
        Int alignment_disk_size = 100
        Int pilon_memory = 32
    }
    call bwa_task.bwa {
        input:
            read1 = reads_1,
            read2 = reads_2,
            samplename = samplename,
            reference_genome = reference_fasta,
            cpu = alignment_cpu,
            disk_size = alignment_disk_size
    }
    call pilon_task.pilon {
        input:
            assembly = reference_fasta,
            bam = bwa.sorted_bam,
            bai = bwa.sorted_bai,
            samplename = samplename,
            fix = "bases",
            memory = pilon_memory
    }
    call bcftools_view_task.bcftools_view as variants_view{
        input:
            vcf = pilon.vcf,
            samplename = samplename,
            output_type = "v",
            output_extension = "vcf",
            query = "-i \'INFO/AC > 0\' -f \'PASS,.\'"
    }
    call bcftools_view_task.bcftools_view as full_view {
        input:
            vcf = pilon.vcf,
            samplename = samplename,
            output_type = "z",
            output_extension = "vcf.gz",
            query = ""
    }
    output {
        File variants_vcf = variants_view.output_vcf
        File full_vcf = full_view.output_vcf
        String pilon_version = pilon.pilon_version
        String pilon_docker = pilon.pilon_docker
        String bwa_version = bwa.bwa_version
    }
}