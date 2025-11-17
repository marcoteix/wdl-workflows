version 1.0

import "../tasks/task_cleansweep_collection.wdl" as cleansweep_collection_task
import "../tasks/task_multivcf_to_msa.wdl" as multivcf_to_msa_task
import "../tasks/task_gubbins.wdl" as gubbins_task
import "../tasks/task_iqtree2.wdl" as iqtree2_task
import "../tasks/task_snp_dists.wdl" as snp_dists_task
import "../tasks/task_vcf_add_reference.wdl" as add_reference_task

workflow cleansweep_vcf_to_tree {
    input {
        String collection_name
        Array[String] samplenames
        Array[File] variants_vcfs
        Float min_ani = 0.998
        Boolean use_gubbins = true
        Int min_coverage = 10
    }
    # Convert a set of VCFs to a multisequence alignment FASTA
    call cleansweep_collection_task.cleansweep_collection {
        input:
            samplenames = samplenames,
            vcfs = variants_vcfs,
            collection_name = collection_name,
            min_ani = min_ani,
            min_coverage = min_coverage
    }
    call add_reference_task.vcf_add_reference {
        input:
            merged_vcf = cleansweep_collection.merged_vcf,
            collection_name = collection_name
    }
    call multivcf_to_msa_task.multivcf_to_msa {
        input:
            vcf = vcf_add_reference.vcf_out,
            collection_name = collection_name
    }
    # Mask recombinant regions with Gubbins
    if (use_gubbins) {
        call gubbins_task.gubbins {
            input:
                alignment = multivcf_to_msa.msa,
                cluster_name = collection_name
        }
    }
    # Create a ML tree with IQTree2
    call iqtree2_task.iqtree2 {
        input:
            alignment = select_first([gubbins.gubbins_fasta, multivcf_to_msa.msa]),
            cluster_name = collection_name
    }
    # Create a pairwise SNP matrix
    call snp_dists_task.snp_dists {
        input:
            alignment = select_first([gubbins.gubbins_fasta, multivcf_to_msa.msa]),
            cluster_name = collection_name
    }
    output {

        File msa_fasta = select_first([gubbins.gubbins_fasta, multivcf_to_msa.msa])
        File merged_vcf = vcf_add_reference.vcf_out
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