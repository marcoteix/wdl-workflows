version 1.0

import "../tasks/task_rgi.wdl" as rgi_task

workflow rgi {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "AMR gene detection from short reads with RGI bwt and the CARD database."
    }
    input {
        String samplename
        # Quality-controlled and trimmed reads; omit read2 for single-end reads
        File read1
        File? read2
        # CARD data archive from https://card.mcmaster.ca/latest/data
        File card_data_tarball
        # Read aligner: "kma" (default), "bowtie2", or "bwa".
        # Read depth is only reported in the allele-level report when using KMA.
        String aligner = "kma"
    }
    # Align reads to CARD and report AMR genes at the allele and gene level
    call rgi_task.rgi_bwt {
        input:
            read1 = read1,
            read2 = read2,
            samplename = samplename,
            card_data_tarball = card_data_tarball,
            aligner = aligner
    }
    output {
        # RGI bwt reports
        File rgi_allele_mapping_data = rgi_bwt.rgi_allele_mapping_data
        File rgi_gene_mapping_data = rgi_bwt.rgi_gene_mapping_data
        File rgi_artifacts_mapping_stats = rgi_bwt.rgi_artifacts_mapping_stats
        File rgi_overall_mapping_stats = rgi_bwt.rgi_overall_mapping_stats
        File rgi_reference_mapping_stats = rgi_bwt.rgi_reference_mapping_stats

        # Comma-separated list of detected AMR genes
        String rgi_amr_genes = rgi_bwt.rgi_amr_genes

        # Software and database versions
        String rgi_version = rgi_bwt.rgi_version
        String card_version = rgi_bwt.card_version
        String rgi_docker = rgi_bwt.rgi_docker
    }
}
