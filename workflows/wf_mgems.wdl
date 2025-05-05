version 1.0

import "../tasks/task_find_straingst_fasta.wdl" as find_straingst_fasta_task
import "../tasks/task_themisto.wdl" as themisto_task
import "../tasks/task_msweep.wdl" as msweep_task
import "../tasks/task_mgems.wdl" as mgems_task
import "../tasks/task_bwa.wdl" as bwa_task
import "../tasks/task_shovill.wdl" as shovill_task
import "../tasks/task_pilon.wdl" as pilon_task
import "../tasks/task_find_straingst_fasta.wdl" as find_straingst_fasta_task
import "../tasks/task_bcftools_view.wdl" as bcftools_view_task 

workflow mgems_from_straingst {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Calls variants from plate swipe data with mGEMS and Pilon, given a set of StraniGST outputs."
    }
    input {
        String samplename
        File reads1 
        File reads2
        String query_strain
        Array[File] straingst_strains
        String straingst_fasta_location
        # Themisto options
        String themisto_docker_image = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/themisto:3.2.2"
        Int themisto_kmer_size = 31
        Int themisto_cpu = 4
        Int themisto_memory = 32
        Int themisto_disk_size = 64
        # mSWEEP options
        String msweep_docker_image = "quay.io/biocontainers/msweep:2.2.1--h503566f_1"
        Int msweep_cpu = 4
        Int msweep_memory = 16
        Int msweep_disk_size = 64
        # mGEMS options
        String mgems_docker_image = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/mgems:1.3.3"
        Int mgems_cpu = 1
        Int mgems_memory = 16
        Int mgems_disk_size = 64
        # bwa options
        Int bwa_cpu = 4
        Int bwa_disk_size = 64
        Int bwa_memory = 32 
        # Pilon options
        Int pilon_memory = 32
        Int pilon_disk_size = 64
    }
    call find_straingst_fasta_task.find_straingst_fasta {
        input:
            query_strain = query_strain,
            straingst_strains = straingst_strains,
            fasta_location = straingst_fasta_location
    }
    call themisto_task.themisto {
        input:
            references = find_straingst_fasta.all_strains_fasta,
            reference_names = find_straingst_fasta.strain_names,
            reads1 = reads1,
            reads2 = reads2,
            samplename = samplename,
            docker = themisto_docker_image,
            kmer_size = themisto_kmer_size,
            cpu = themisto_cpu,
            memory = themisto_memory,
            disk_size = themisto_disk_size
    }
    call msweep_task.msweep {
        input:
            alignment_1 = themisto.themisto_alignment1,
            alignment_2 = themisto.themisto_alignment2,
            clustering = themisto.clustering,
            samplename = samplename,
            docker = msweep_docker_image
    }
    call mgems_task.mgems {
        input:
            reads_1 = reads1,
            reads_2 = reads2,
            themisto_index = themisto.themisto_index,
            alignment_1 = themisto_alignment1,
            alignment_2 = themisto_alignment2,
            msweep_probabilities = msweep.msweep_probabilities,
            msweep_abundances = msweep.msweep_abundances,
            clustering = themisto.clustering,
            samplename = samplename,
            query = query_strain,
            docker = mgems_docker_image,
            cpu = mgems_cpu,
            memory = mgems_memory,
            disk_size = mgems_disk_size
    }
    call bwa_task.bwa {
        input:
            read1 = mgems.mgems_query_reads_1,
            read2 = mgems.mgems_query_reads_2,
            samplename = samplename,
            reference_genome = find_straingst_fasta.query_fasta,
            cpu = bwa_cpu,
            disk_size = bwa_disk_size,
            memory = bwa_memory
    }
    call pilon_task.pilon {
        input:
            assembly = find_straingst_fasta.query_fasta,
            bam = bwa.sorted_bam,
            bai = bwa.sorted_bai,
            samplename = samplename,
            fix = "bases",
            memory = pilon_memory,
            disk_size = pilon_disk_size
    }
    call bcftools_view_task.bcftools_view {
        input:
            vcf = pilon.vcf,
            samplename = samplename,
            output_type = "v",
            output_extension = "vcf",
            query = "-i \'INFO/AC > 0\' -f \'PASS,.\'"
    }
    output {
        # Themisto outputs
        File themisto_alignment1 = themisto.themisto_alignment1
        File themisto_alignment2 = themisto.themisto_alignment2
        File themisto_index = themisto.themisto_index
        File clustering = themisto.clustering
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
        # BWA and Pilon outputs
        File variants_vcf = bcftools_view.output_vcf
        String pilon_version = pilon.pilon_version
        String pilon_docker = pilon.pilon_docker
        String bwa_version = bwa.bwa_version
    }
}