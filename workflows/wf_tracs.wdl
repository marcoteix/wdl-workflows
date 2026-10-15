version 1.0

import "../tasks/task_tracs_check_inputs.wdl" as tracs_check_inputs_task
import "../tasks/task_tracs_find_straingst_references.wdl" as tracs_find_straingst_references_task
import "../tasks/task_tracs_build_db.wdl" as tracs_build_db_task
import "../tasks/task_tracs_align.wdl" as tracs_align_task
import "../tasks/task_tracs_combine.wdl" as tracs_combine_task
import "../tasks/task_tracs_distance.wdl" as tracs_distance_task

# Computes the SNP distances between the bacterial strains in a set of metagenomic samples
# with TRACS (https://gthlab.au/tracs/#/README):
#   1. Builds a TRACS database per sample from the sample's reference FASTAs, either given
#      directly or found from the sample's StrainGST results.
#   2. Aligns each sample's reads to its database with TRACS align.
#   3. Combines the per-sample alignments into one MSA per reference with TRACS combine.
#   4. Computes the pairwise SNP distances in each MSA with TRACS distance.
# Only references found in two or more samples are reported. Samples without references,
# or in which TRACS finds none of their references, are skipped.

workflow tracs {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Strain-level SNP distances between metagenomic samples with TRACS."
    }
    input {
        # One entry per sample, in the same order in every per-sample input.
        # Sample names must be unique and cannot contain whitespace or "/".
        Array[String] samplenames
        # Paired-end reads (FASTQ, optionally gzipped)
        Array[File] reads1
        Array[File] reads2

        # References used to build each sample's TRACS database. Provide exactly one of:
        #   a) reference_fastas, or
        #   b) straingst_strains and straingst_fasta_location.
        # References are named after their FASTA file without extensions (StrainGST strain
        # name in option b); references with the same name in different samples are
        # compared with each other.

        # a) Reference FASTAs (optionally gzipped) of each sample
        Array[Array[File]]? reference_fastas
        # b) StrainGST strain report (*.strains.tsv) of each sample, one file per sample.
        #    Samples with several reports (e.g. one per StrainGST database) must have them
        #    merged first with workflows/wf_tracs_merge_straingst_reports.wdl: when this
        #    workflow runs on a Terra set, Terra flattens per-sample lists of reports into
        #    one list, losing which report belongs to which sample.
        Array[File]? straingst_strains
        # b) Location (e.g. gs://bucket/path) of the StrainGST reference FASTAs, shared by
        #    all samples. The FASTA of each strain must be at
        #    <straingst_fasta_location>/<strain name><straingst_fasta_extension>.
        String? straingst_fasta_location
        String straingst_fasta_extension = ".fa"

        # Also report SNP distances that exclude SNPs likely caused by recombination
        Boolean filter_recombination = true
        String tracs_docker_image = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
    }

    # ----------------- Check inputs -----------------
    # An empty optional array (e.g. [] passed from Terra when a column has no value)
    # is treated the same as absent. Short-circuit && ensures select_first is only
    # called when the array is actually defined (non-null).
    Boolean use_reference_fastas = defined(reference_fastas) && length(select_first([reference_fastas])) > 0
    Boolean use_straingst_strains = defined(straingst_strains) && length(select_first([straingst_strains])) > 0

    # Count the entries of the optional per-sample inputs, if given
    if (use_reference_fastas) {
        Int n_reference_fastas = length(select_first([reference_fastas]))
    }
    if (use_straingst_strains) {
        Int n_straingst_strains = length(select_first([straingst_strains]))
    }
    # Fail early if the inputs are inconsistent. The samples are only processed once
    # this check passes.
    call tracs_check_inputs_task.tracs_check_inputs {
        input:
            samplenames = samplenames,
            n_reads1 = length(reads1),
            n_reads2 = length(reads2),
            n_reference_fastas = n_reference_fastas,
            n_straingst_strains = n_straingst_strains,
            straingst_fasta_location_given = defined(straingst_fasta_location),
            docker = tracs_docker_image
    }

    # ----------------- Per-sample database and alignment -----------------
    scatter (idx in range(tracs_check_inputs.n_samples)) {
        String samplename = samplenames[idx]

        # Find the sample's reference FASTAs: (a) given directly, or (b) the FASTAs of the
        # strains detected by StrainGST
        if (use_reference_fastas) {
            Array[File] given_reference_fastas = select_first([reference_fastas])[idx]
        }
        if (use_straingst_strains) {
            call tracs_find_straingst_references_task.tracs_find_straingst_references {
                input:
                    # Wrap the single file in an array; the task accepts Array[File] to
                    # support future multi-report scenarios without interface changes.
                    straingst_strains = [select_first([straingst_strains])[idx]],
                    fasta_location = select_first([straingst_fasta_location]),
                    fasta_extension = straingst_fasta_extension,
                    docker = tracs_docker_image
            }
        }
        Array[File] sample_reference_fastas = select_first([
            given_reference_fastas,
            tracs_find_straingst_references.reference_fastas
        ])

        # Samples without references are skipped
        if (length(sample_reference_fastas) > 0) {
            # Build a TRACS database with the sample's references
            call tracs_build_db_task.tracs_build_db {
                input:
                    samplename = samplename,
                    reference_fastas = sample_reference_fastas,
                    docker = tracs_docker_image
            }
            # Align the sample's reads to the references in its database
            call tracs_align_task.tracs_align {
                input:
                    samplename = samplename,
                    read1 = reads1[idx],
                    read2 = reads2[idx],
                    tracs_database = tracs_build_db.tracs_database,
                    docker = tracs_docker_image
            }
        }

        # Record the samples with no alignments: those without references, and those in
        # which TRACS found none of their references
        if (!select_first([tracs_align.has_alignments, false])) {
            String skipped_sample = samplename
        }
    }

    # ----------------- Combine samples -----------------
    # Build one MSA per reference found in two or more samples
    call tracs_combine_task.tracs_combine {
        input:
            alignment_archives = select_all(tracs_align.alignment_archive),
            docker = tracs_docker_image
    }

    # ----------------- SNP distances -----------------
    # Compute the pairwise SNP distances between the samples in each MSA
    scatter (msa in tracs_combine.combined_msas) {
        call tracs_distance_task.tracs_distance {
            input:
                msa = msa,
                filter_recombination = filter_recombination,
                docker = tracs_docker_image
        }
    }

    output {
        # One MSA (gzipped FASTA) per reference found in two or more samples, named
        # <reference>_combined.fasta.gz. Sequences are named after the samples.
        Array[File] tracs_msas = tracs_combine.combined_msas
        # One pairwise SNP distance table (CSV) per MSA, in the same order as tracs_msas,
        # named <reference>_tracs_distances.csv
        Array[File] tracs_snp_distances = tracs_distance.snp_distances
        # Samples with no alignments, left out of the MSAs and distances
        Array[String] tracs_skipped_samples = select_all(skipped_sample)

        # Software version and Docker image
        String tracs_version = tracs_combine.tracs_version
        String tracs_docker = tracs_combine.tracs_docker
    }
}
