version 1.0

# Aligns a sample's paired-end reads to the references in its TRACS database, and writes one
# alignment (FASTA) per reference present in the sample.
# TRACS align first uses sourmash to find which database references are present in the
# reads, aligns the reads to each of them with minimap2, and then estimates the alleles at
# every position. Positions with too little read coverage are set to N.
#   TRACS documentation: https://gthlab.au/tracs/#/alignment
#
# If sourmash finds none of the database references in the reads, the sample is skipped:
# the task logs a warning and returns an empty alignment archive instead of failing.

task tracs_align {
  input {
    # Sample name. Used as the prefix of the output files and as the name of the
    # sample's sequences in the combined MSAs.
    String samplename
    # Paired-end reads (FASTQ, optionally gzipped)
    File read1
    File read2
    # TRACS database of the sample, created with tracs_build_db
    File tracs_database
    # Minimum read coverage; positions with lower coverage are set to N (TRACS --min-cov)
    Int min_coverage = 5
    # Threshold to exclude likely erroneous variants (TRACS --error-perc)
    Float error_threshold = 0.01
    # Minimum base quality (TRACS -Q)
    Int min_base_quality = 0
    # Minimum mapping quality (TRACS -q)
    Int min_mapping_quality = 0
    # Require variants to be supported by reads on both strands. Set to false to drop this
    # requirement (TRACS --either-strand).
    Boolean require_both_strands = true
    Int cpu = 4
    Int memory = 16
    Int disk_size = 100
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
  }
  command <<<
    set -euo pipefail

    # Log the date and TRACS version
    date
    tracs --version

    # ---------------------------------------------------------------------------------
    # Align the reads to the references in the database
    # The output directory is named after the sample, because TRACS combine names each
    # sample after the directory holding its alignments.
    # ---------------------------------------------------------------------------------
    # Whether sourmash found any of the database references in the reads
    references_found=true

    if tracs align \
      -i ~{read1} ~{read2} \
      --database ~{tracs_database} \
      -o ~{samplename} \
      -p ~{samplename} \
      --min-cov ~{min_coverage} \
      --error-perc ~{error_threshold} \
      -Q ~{min_base_quality} \
      -q ~{min_mapping_quality} \
      ~{true="" false="--either-strand" require_both_strands} \
      -t ~{cpu} \
      2>&1 | tee tracs_align.log
    then
      echo "TRACS align finished."
    elif grep -q "No reference genomes were found" tracs_align.log; then
      # TRACS exits with an error when sourmash finds none of the database references in
      # the reads. Skip the sample instead of failing the workflow.
      echo "WARNING: none of the references in the database were found in the reads of ~{samplename}. The sample will be skipped." >&2
      references_found=false
      mkdir -p ~{samplename}
    else
      echo "ERROR: TRACS align failed. See the log above." >&2
      exit 1
    fi

    # ---------------------------------------------------------------------------------
    # Package the alignments
    # Only the alignment FASTAs (<sample>_posterior_counts_ref_<reference>.fasta) are
    # needed downstream; the pileups and allele count tables are left out to keep the
    # archive small. TRACS writes no FASTA for a reference if less than 25% of its genome
    # had enough read coverage.
    # ---------------------------------------------------------------------------------
    shopt -s nullglob
    alignments=( ~{samplename}/*_posterior_counts_ref_*.fasta )
    mkdir -p archive/~{samplename}

    if (( ${#alignments[@]} > 0 )); then
      echo "${#alignments[@]} reference(s) aligned in ~{samplename}."
      cp "${alignments[@]}" archive/~{samplename}/
      echo "true" > HAS_ALIGNMENTS
    else
      if [[ "${references_found}" == "true" ]]; then
        echo "WARNING: no reference had enough read coverage in ~{samplename}. The sample will be skipped." >&2
      fi
      echo "false" > HAS_ALIGNMENTS
    fi

    tar -czf ~{samplename}_tracs_align.tar.gz -C archive ~{samplename}
  >>>
  output {
    # Archive with a directory named after the sample, holding one alignment FASTA per
    # reference found in the sample (empty if none was found)
    File alignment_archive = "~{samplename}_tracs_align.tar.gz"
    # Whether at least one reference was found and aligned
    Boolean has_alignments = read_boolean("HAS_ALIGNMENTS")
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
