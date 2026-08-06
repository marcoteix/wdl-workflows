version 1.0

import "../tasks/task_cleansweep_collection.wdl" as cleansweep_collection_task
import "../tasks/task_vcf_to_fasta.wdl" as vcf_to_fasta_task
import "../tasks/task_fastas_to_msa.wdl" as fastas_to_msa_task
import "../tasks/task_filter_msa_sites.wdl" as filter_msa_sites_task
import "../tasks/task_gubbins.wdl" as gubbins_task
import "../tasks/task_iqtree2.wdl" as iqtree2_task
import "../tasks/task_snp_dists.wdl" as snp_dists_task

workflow isolate_plate_swipe_tree {
    input {
        String collection_name
        Array[String] plate_swipe_names
        Array[File] plate_swipe_vcfs
        Array[String] isolate_names
        Array[File] isolate_vcfs
        File reference_fasta
        Float cleansweep_alpha = 10.0
        Boolean cleansweep_exclude = false
        Boolean use_gubbins = true
        Boolean remove_missing_loci = false
        Int plate_swipe_min_coverage = 10
        Int isolate_min_coverage = 10
        Float max_missing_pct = 20.0
        Int cleansweep_memory = 32
    }
    # ----------------- Plate swipes -----------------
    # Merge plate swipe VCFs and detect outlier samples with cleansweep
    call cleansweep_collection_task.cleansweep_collection {
        input:
            samplenames = plate_swipe_names,
            vcfs = plate_swipe_vcfs,
            reference_fasta = reference_fasta,
            collection_name = collection_name,
            alpha = cleansweep_alpha,
            min_coverage = plate_swipe_min_coverage,
            exclude = cleansweep_exclude,
            memory = cleansweep_memory
    }
    # ----------------- Isolates -----------------
    # Convert each isolate VCF to a whole-genome FASTA
    scatter (pair in zip(isolate_names, isolate_vcfs)) {
        call vcf_to_fasta_task.vcf_to_fasta as isolate_vcf_to_fasta {
            input:
                vcf = pair.right,
                sequence_name = pair.left,
                min_dp = isolate_min_coverage
        }
    }
    # ----------------- Merge data types -----------------
    # Assemble all FASTAs into a joint MSA; filters samples with excessive missing data
    call fastas_to_msa_task.fastas_to_msa {
        input:
            fastas = flatten([[cleansweep_collection.msa_fasta], isolate_vcf_to_fasta.fasta]),
            reference_fasta = reference_fasta,
            collection_name = collection_name,
            max_missing_pct = max_missing_pct
    }
    # Remove alignment positions with any unknown base (N or -)
    if (remove_missing_loci) {
        call filter_msa_sites_task.filter_msa_sites {
            input:
                msa = fastas_to_msa.msa,
                collection_name = collection_name
        }
    }
    # Mask recombinant regions with Gubbins
    if (use_gubbins) {
        call gubbins_task.gubbins {
            input:
                alignment = select_first([filter_msa_sites.filtered_msa, fastas_to_msa.msa]),
                cluster_name = collection_name
        }
    }
    # Create a ML tree with IQTree2
    call iqtree2_task.iqtree2 {
        input:
            alignment = select_first([gubbins.gubbins_fasta, filter_msa_sites.filtered_msa, fastas_to_msa.msa]),
            cluster_name = collection_name
    }
    # Create a pairwise SNP matrix
    call snp_dists_task.snp_dists {
        input:
            alignment = select_first([gubbins.gubbins_fasta, filter_msa_sites.filtered_msa, fastas_to_msa.msa]),
            cluster_name = collection_name
    }
    output {
        File msa_fasta = select_first([gubbins.gubbins_fasta, filter_msa_sites.filtered_msa, fastas_to_msa.msa])
        File plate_swipe_msa_fasta = cleansweep_collection.msa_fasta

        # Sample filtering outputs
        Array[String] collection_excluded_samples = cleansweep_collection.excluded_samples
        Array[String] low_cov_samples = fastas_to_msa.excluded_samples

        # MSA site filtering outputs
        Int? excluded_msa_sites = filter_msa_sites.excluded_sites_count
        Float? excluded_msa_sites_pct = filter_msa_sites.excluded_sites_pct
        File vcf_to_tree_final_tree = iqtree2.ml_tree

        # Gubbins outputs
        String? gubbins_docker = gubbins.gubbins_docker
        String? gubbins_version = gubbins.gubbins_version
        File? gubbins_recombination_gff = gubbins.gubbins_recombination_gff
        File? gubbins_branch_stats = gubbins.gubbins_branch_stats

        # IQTree2 outputs
        String iqtree2_version = iqtree2.iqtree2_version
        String iqtree2_docker = iqtree2.iqtree2_docker
        String iqtree2_model_used = iqtree2.iqtree2_model_used
        String vcf_to_tree_date = iqtree2.date

        # SNP dists outputs
        String snp_dists_version = snp_dists.snp_dists_version
        String snp_dists_docker = snp_dists.snp_dists_docker
        File vcf_to_tree_snp_matrix = snp_dists.snp_matrix
    }
}
