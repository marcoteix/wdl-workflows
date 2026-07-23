version 1.0

import "../tasks/task_cleansweep_collection.wdl" as cleansweep_collection_task
import "../tasks/task_multivcf_to_msa.wdl" as multivcf_to_msa_task
import "../tasks/task_merge_multivcfs.wdl" as merge_multivcfs_task
import "../tasks/task_merge_vcfs.wdl" as merge_vcfs_task
import "../tasks/task_filter_vcf_samples.wdl" as filter_vcf_samples_task
import "../tasks/task_filter_msa_sites.wdl" as filter_msa_sites_task
import "../tasks/task_gubbins.wdl" as gubbins_task
import "../tasks/task_iqtree2.wdl" as iqtree2_task
import "../tasks/task_snp_dists.wdl" as snp_dists_task
import "../tasks/task_vcf_add_reference.wdl" as add_reference_task

workflow isolate_plate_swipe_tree {
    input {
        String collection_name
        Array[String] plate_swipe_names
        Array[File] plate_swipe_vcfs
        Array[String] isolate_names
        Array[File] isolate_vcfs
        Float cleansweep_alpha = 10.0
        Boolean cleansweep_exclude = false
        Boolean use_gubbins = true
        Boolean remove_missing_loci = false
        Int plate_swipe_min_coverage = 10
        Float plate_swipe_max_missing_pct = 20.0
        Float isolate_max_missing_pct = 20.0
        String isolate_vcf_filters = "PASS,."
        String? isolate_vcf_include
    }
    # ----------------- Plate swipes -----------------
    # Convert plate sweep VCFs to a multisequence alignment FASTA
    call cleansweep_collection_task.cleansweep_collection {
        input:
            samplenames = plate_swipe_names,
            vcfs = plate_swipe_vcfs,
            collection_name = collection_name,
            alpha = cleansweep_alpha,
            min_coverage = plate_swipe_min_coverage,
            exclude = cleansweep_exclude
    }
    call add_reference_task.vcf_add_reference as plate_swipe_add_reference {
        input:
            merged_vcf = cleansweep_collection.merged_vcf,
            collection_name = collection_name
    }
    # Remove samples with excessive missing data before alignment conversion
    call filter_vcf_samples_task.filter_vcf_samples as plate_swipe_filter_vcf {
        input:
            vcf = plate_swipe_add_reference.vcf_out,
            collection_name = collection_name,
            max_missing_pct = plate_swipe_max_missing_pct
    }
    # ----------------- Isolates -----------------
    # Merge per-sample VCFs into a multi-sample VCF
    call merge_vcfs_task.merge_vcfs as merge_isolate_vcf {
        input:
            samplenames = isolate_names,
            vcfs = isolate_vcfs,
            collection_name = collection_name,
            filters = isolate_vcf_filters,
            include = isolate_vcf_include
    }
    call add_reference_task.vcf_add_reference as isolate_add_reference {
        input:
            merged_vcf = merge_isolate_vcf.merged_vcf,
            collection_name = collection_name
    }
    # Remove samples with excessive missing data before alignment conversion
    call filter_vcf_samples_task.filter_vcf_samples as isolate_filter_vcf {
        input:
            vcf = isolate_add_reference.vcf_out,
            collection_name = collection_name,
            max_missing_pct = isolate_max_missing_pct
    }
    # ----------------- Merge data types -----------------
    call merge_multivcfs_task.merge_multivcfs {
        input: 
            vcfs = [plate_swipe_filter_vcf.filtered_vcf, isolate_filter_vcf.filtered_vcf],
            collection_name = collection_name,
    }
    # Convert merged VCF into a MSA FASTA
    call multivcf_to_msa_task.multivcf_to_msa as vcf_to_msa {
        input:
            vcf = merge_multivcfs.merged_vcf,
            collection_name = collection_name
    }
    # Remove alignment positions with any unknown base (N or -)
    if (remove_missing_loci) {
        call filter_msa_sites_task.filter_msa_sites {
            input:
                msa = vcf_to_msa.msa,
                collection_name = collection_name
        }
    }
    # Mask recombinant regions with Gubbins
    if (use_gubbins) {
        call gubbins_task.gubbins {
            input:
                alignment = select_first([filter_msa_sites.filtered_msa, vcf_to_msa.msa]),
                cluster_name = collection_name
        }
    }
    # Create a ML tree with IQTree2
    call iqtree2_task.iqtree2 {
        input:
            alignment = select_first([gubbins.gubbins_fasta, filter_msa_sites.filtered_msa, vcf_to_msa.msa]),
            cluster_name = collection_name
    }
    # Create a pairwise SNP matrix
    call snp_dists_task.snp_dists {
        input:
            alignment = select_first([gubbins.gubbins_fasta, filter_msa_sites.filtered_msa, vcf_to_msa.msa]),
            cluster_name = collection_name
    }
    output {
        File msa_fasta = select_first([gubbins.gubbins_fasta, filter_msa_sites.filtered_msa, vcf_to_msa.msa])
        File merged_vcf = merge_multivcfs.merged_vcf

        # Sample filtering outputs
        Array[String] collection_excluded_samples = cleansweep_collection.excluded_samples
        Array[String] low_cov_plate_swipes = plate_swipe_filter_vcf.excluded_samples
        Array[String] low_cov_isolates = isolate_filter_vcf.excluded_samples

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