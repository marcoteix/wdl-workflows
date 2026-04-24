version 1.0

import "../tasks/task_metaspades.wdl" as metaspades_task
import "../tasks/task_plasmaag.wdl" as plasmaag_task
import "../tasks/task_mob_typer.wdl" as mob_typer_task
import "../tasks/task_plasmer.wdl" as plasmer_task
import "../tasks/task_mmseqs2_createdb.wdl" as mmseqs2_createdb_task
import "../tasks/task_mmseqs2_assembly_search.wdl" as mmseqs2_search_task

workflow plasmaag_wf {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Assembles paired-end reads with metaSPAdes, identifies candidate plasmids/chromosomes/viruses with PlasMAAG, annotates plasmids with MOB-typer and Plasmer, and maps each sample's assembly contigs back to the discovered plasmid catalog with mmseqs2."
    }
    input {
        Array[File] reads1
        Array[File] reads2
        Array[String] samplenames
        Array[File] assemblies
        File genomad_db
        File plasmer_database
        String collection_name = "plasmaag"
        Boolean run_mmseqs2_search = true
        Int min_contig_length = 1000
        Int max_hits_per_contig = 5
    }

    # 1. Assemble each sample with metaSPAdes (parallel)
    scatter (idx in range(length(samplenames))) {
        call metaspades_task.metaspades {
            input:
                read1 = reads1[idx],
                read2 = reads2[idx],
                samplename = samplenames[idx]
        }
    }

    # 2. Run PlasMAAG once on all samples
    call plasmaag_task.plasmaag {
        input:
            reads1 = reads1,
            reads2 = reads2,
            samplenames = samplenames,
            assembly_archives = metaspades.assembly_archive,
            genomad_db = genomad_db,
            collection_name = collection_name
    }

    # 3. MOB-typer on the concatenated candidate plasmids
    call mob_typer_task.mob_typer {
        input:
            plasmid_fasta = plasmaag.candidate_plasmids_fasta,
            samplename = collection_name
    }

    # 4. Plasmer on the concatenated candidate plasmids
    call plasmer_task.plasmer {
        input:
            assembly_fasta = plasmaag.candidate_plasmids_fasta,
            plasmer_database = plasmer_database,
            samplename = collection_name
    }

    # 5a. Build an mmseqs2 database from the concatenated candidate plasmids
    call mmseqs2_createdb_task.mmseqs2_createdb {
        input:
            fasta = plasmaag.candidate_plasmids_fasta,
            reference_name = collection_name + "_plasmids"
    }

    # 5b. Per-sample mmseqs2 search of assembly contigs vs. the plasmid catalog (parallel, optional)
    if (run_mmseqs2_search) {
        scatter (idx in range(length(samplenames))) {
            call mmseqs2_search_task.mmseqs2_assembly_search {
                input:
                    assembly = assemblies[idx],
                    reference = mmseqs2_createdb.mmseqs2_database,
                    reference_name = collection_name + "_plasmids",
                    samplename = samplenames[idx],
                    min_contig_length = min_contig_length,
                    max_hits_per_contig = max_hits_per_contig
            }
        }
    }

    output {
        # Concatenated FASTAs from PlasMAAG
        File candidate_plasmids_fasta = plasmaag.candidate_plasmids_fasta
        File candidate_chromosomes_fasta = plasmaag.candidate_chromosomes_fasta
        File candidate_virus_fasta = plasmaag.candidate_virus_fasta

        # PlasMAAG TSVs
        File candidate_plasmids_tsv = plasmaag.candidate_plasmids_tsv
        File candidate_genomes_tsv = plasmaag.candidate_genomes_tsv
        File candidate_virus_tsv = plasmaag.candidate_virus_tsv
        File plasmaag_scores_tsv = plasmaag.scores_tsv

        # MOB-typer
        File mob_typer_results = mob_typer.mob_typer_results

        # Plasmer
        File plasmer_probabilities = plasmer.plasmer_probabilities
        File plasmer_classes = plasmer.plasmer_classes
        File plasmer_plasmid_taxa = plasmer.plasmer_plasmid_taxa
        File plasmer_plasmid_fasta = plasmer.plasmer_plasmid_fasta

        # mmseqs2 reference database with candidate plasmids (always emitted)
        File mmseqs2_plasmid_database = mmseqs2_createdb.mmseqs2_database

        # mmseqs2 per-sample search results (only if run_mmseqs2_search = true)
        Array[File]? mmseqs2_alignments = mmseqs2_assembly_search.mmseqs2_alignment

        # Versions and dockers
        String metaspades_version = metaspades.metaspades_version[0]
        String metaspades_docker = metaspades.metaspades_docker[0]
        String plasmaag_version = plasmaag.plasmaag_version
        String plasmaag_docker = plasmaag.plasmaag_docker
        String mob_typer_version = mob_typer.mob_typer_version
        String mob_typer_docker = mob_typer.mob_typer_docker
        String plasmer_version = plasmer.plasmer_version
        String plasmer_docker = plasmer.plasmer_docker
        String mmseqs2_version = mmseqs2_createdb.mmseqs2_version
        String mmseqs2_docker = mmseqs2_createdb.mmseqs2_docker
    }
}
