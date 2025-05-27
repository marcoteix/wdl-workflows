version 1.0

import "../tasks/task_bwa.wdl" as bwa_task
import "../tasks/task_pilon.wdl" as pilon_task
import "../tasks/task_find_straingst_fasta.wdl" as find_straingst_fasta_task
import "../tasks/task_concat_files.wdl" as concat_files_task
import "../tasks/task_bcftools_view.wdl" as bcftools_view_task

workflow pilon_plate_swipe {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Pipeline for variant calling with Pilon."
    }
    input {
        String samplename
        File reads_1
        File reads_2
        String query_strain
        Array[File] straingst_strains
        String fasta_location
        Int alignment_cpu = 6
        Int alignment_disk_size = 32
        Int alignment_memory = 32 
        Int pilon_memory = 32
        Int pilon_disk_size = 32
    }
    call find_straingst_fasta_task.find_straingst_fasta {
        input:
            query_strain = query_strain,
            straingst_strains = straingst_strains,
            fasta_location = fasta_location
    }
    call concat_files_task.concat_files {
        input:
            files = find_straingst_fasta.background_fasta,
            base_file = find_straingst_fasta.query_fasta,
            extension = "fa"
    }
    call bwa_task.bwa {
        input:
            read1 = reads_1,
            read2 = reads_2,
            samplename = samplename,
            reference_genome = concat_files.concatenated,
            cpu = alignment_cpu,
            disk_size = alignment_disk_size,
            memory = alignment_memory
    }
    call pilon_task.pilon {
        input:
            assembly = concat_files.concatenated,
            bam = bwa.sorted_bam,
            bai = bwa.sorted_bai,
            samplename = samplename,
            fix = "bases",
            memory = pilon_memory,
            disk_size = pilon_disk_size
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