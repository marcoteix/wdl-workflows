version 1.0

# Computes the pairwise SNP distances between the samples in a TRACS MSA (one reference).
#   TRACS documentation: https://gthlab.au/tracs/#/distance

task tracs_distance {
  input {
    # MSA of one reference, created with tracs_combine (<reference>_combined.fasta.gz)
    File msa
    # Also report SNP distances that exclude SNPs likely caused by recombination
    # (TRACS --filter)
    Boolean filter_recombination = true
    Int cpu = 2
    Int memory = 8
    Int disk_size = 20
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
  }
  # Name of the reference the MSA was built from
  String reference_name = basename(msa, "_combined.fasta.gz")
  command <<<
    set -euo pipefail

    # Log the date and TRACS version
    date
    tracs --version

    # Distances are computed for every pair of samples in the MSA
    tracs distance \
      --msa ~{msa} \
      -o ~{reference_name}_tracs_distances.csv \
      ~{true="--filter" false="" filter_recombination} \
      -t ~{cpu}
  >>>
  output {
    # CSV with one row per pair of samples. Main columns:
    #   sampleA, sampleB: sample names
    #   SNP distance: number of SNPs between the two samples
    #   filtered SNP distance: SNP distance excluding SNPs likely caused by recombination
    #     (0 if filter_recombination is false)
    #   sites considered: number of alignment positions compared
    # The date difference, transmission distance, and expected K columns are NA, as no
    # sampling dates are given. The MSA file column is the reference name, cut at the
    # first "." by TRACS.
    File snp_distances = "~{reference_name}_tracs_distances.csv"
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: cpu
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
  }
}
