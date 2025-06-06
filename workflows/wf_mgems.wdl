version 1.0

import "../tasks/task_themisto.wdl" as themisto_task
import "../tasks/task_msweep.wdl" as msweep_task
import "../tasks/task_mgems.wdl" as mgems_task
import "../tasks/task_bwa.wdl" as bwa_task
import "../tasks/task_shovill.wdl" as shovill_task
import "../tasks/task_pilon.wdl" as pilon_task
import "../tasks/task_bcftools_view.wdl" as bcftools_view_task 
import "../tasks/task_shovill.wdl" as shovill_task 
import "../tasks/task_snippy_variants.wdl" as snippy_variants_task 

workflow mgems_standalone {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Calls variants from plate swipe data with mGEMS and Pilon/Snippy."
    }
    input {
        String samplename
        File reads1 
        File reads2
        String query_strain
        File reference_genome
        File themisto_index 
        File clustering
        # Themisto options
        String themisto_docker_image = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/themisto:3.2.2"
        Int themisto_cpu = 4
        Int themisto_memory = 32
        Int themisto_disk_size = 64
        # mSWEEP options
        String msweep_docker_image = "quay.io/biocontainers/msweep:2.2.1--h503566f_1"
        Int msweep_cpu = 4
        Int msweep_memory = 32
        Int msweep_disk_size = 64
        # mGEMS options
        String mgems_docker_image = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/mgems:1.3.3"
        Int mgems_cpu = 1
        Int mgems_memory = 32
        Int mgems_disk_size = 64
        # bwa options
        Int bwa_cpu = 4
        Int bwa_disk_size = 64
        Int bwa_memory = 32 
        # Pilon options
        Int pilon_memory = 32
        Int pilon_disk_size = 64
        # Assembly options
        Boolean run_assembly = false
        String shovill_docker = "us-docker.pkg.dev/general-theiagen/staphb/shovill:1.1.0"
        Int shovill_disk_size = 100
        Int shovill_cpu = 4
        Int shovill_memory = 16
        # Snippy options
        String snippy_docker = "us-docker.pkg.dev/general-theiagen/staphb/snippy:4.6.0"
        Int snippy_cpus = 8
        Int snippy_memory = 32
    }
    call themisto_task.themisto_align as themisto {
        input:
            themisto_index = themisto_index,
            reads1 = reads1,
            reads2 = reads2,
            samplename = samplename,
            docker = themisto_docker_image,
            cpu = themisto_cpu,
            memory = themisto_memory,
            disk_size = themisto_disk_size
    }
    call msweep_task.msweep {
        input:
            alignment_1 = themisto.themisto_alignment1,
            alignment_2 = themisto.themisto_alignment2,
            clustering = clustering,
            samplename = samplename,
            memory = msweep_memory,
            cpu = msweep_cpu,
            docker = msweep_docker_image
    }
    call mgems_task.mgems {
        input:
            reads_1 = reads1,
            reads_2 = reads2,
            themisto_index = themisto_index,
            alignment_1 = themisto_alignment1,
            alignment_2 = themisto_alignment2,
            msweep_probabilities = msweep.msweep_probabilities,
            msweep_abundances = msweep.msweep_abundances,
            clustering = clustering,
            samplename = samplename,
            query = query_strain,
            docker = mgems_docker_image,
            cpu = mgems_cpu,
            memory = mgems_memory,
            disk_size = mgems_disk_size
    }
    if (run_assembly) {
        call shovill_task.shovill_pe {
            input:
                read1_cleaned = mgems.mgems_query_reads_1,
                read2_cleaned = mgems.mgems_query_reads_2,
                samplename = samplename,
                docker = shovill_docker,
                disk_size = shovill_disk_size,
                cpu = shovill_cpu,
                memory = shovill_memory
        }
        call snippy_variants_task.snippy_variants {
            input:
                reference_genome_file = reference_genome,
                contigs = shovill_pe.assembly_fasta,
                samplename = samplename,
                docker = snippy_docker,
                cpus = snippy_cpus,
                memory = snippy_memory
        }
    }
    if (!run_assembly) {
        call bwa_task.bwa {
            input:
                read1 = mgems.mgems_query_reads_1,
                read2 = mgems.mgems_query_reads_2,
                samplename = samplename,
                reference_genome = reference_genome,
                cpu = bwa_cpu,
                disk_size = bwa_disk_size,
                memory = bwa_memory
        }
        call pilon_task.pilon {
            input:
                assembly = reference_genome,
                bam = bwa.sorted_bam,
                bai = bwa.sorted_bai,
                samplename = samplename,
                fix = "bases",
                memory = pilon_memory,
                disk_size = pilon_disk_size
        }
        call bcftools_view_task.bcftools_view as variants_view {
            input:
                vcf = pilon.vcf,
                samplename = samplename,
                output_type = "v",
                output_extension = "vcf",
                query = "-i \'INFO/AC > 0\' -f \'PASS,.\'"
        }
        call bcftools_view_task.bcftools_view as full_view{
            input:
                vcf = pilon.vcf,
                samplename = samplename,
                output_type = "z",
                output_extension = "vcf.gz",
                query = ""
        }
    }
    output {
        # Themisto outputs
        File themisto_alignment1 = themisto.themisto_alignment1
        File themisto_alignment2 = themisto.themisto_alignment2
        String themisto_docker = themisto.themisto_docker
        # mSWEEP outputs
        File msweep_abundances = msweep.msweep_abundances
        File msweep_probabilities = msweep.msweep_probabilities
        String msweep_docker = msweep.msweep_docker
        # mGEMS outputs
        Array[File] mgems_binned_reads = mgems.mgems_binned_reads
        File? mgems_query_reads_1 = mgems.mgems_query_reads_1
        File? mgems_query_reads_2 = mgems.mgems_query_reads_2
        String mgems_docker = mgems.mgems_docker
        # Output VCF
        File variants_vcf = select_first([variants_view.output_vcf, snippy_variants.snippy_variants_vcf])
        File? full_vcf = full_view.output_vcf 
        # BWA and Pilon outputs
        String? pilon_version = pilon.pilon_version
        String? pilon_docker = pilon.pilon_docker
        String? bwa_version = bwa.bwa_version
        # Shovill outputs
        File? assembly_fasta = shovill_pe.assembly_fasta
        String? shovill_version = shovill_pe.shovill_version 
        # Snippy variants outputs
        File? snippy_variants_outdir_tarball = snippy_variants.snippy_variants_outdir_tarball
        File? snippy_variants_vcf = snippy_variants.snippy_variants_vcf
        File? snippy_variants_results = snippy_variants.snippy_variants_results
        String? snippy_variants_version = snippy_variants.snippy_variants_version
        String? snippy_variants_docker = snippy_variants.snippy_variants_docker
    }
}