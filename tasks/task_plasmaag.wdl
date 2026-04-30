version 1.0

task plasmaag {
  # Runs PlasMAAG once across all samples to identify candidate plasmids,
  # chromosomes, and viruses. Concatenates per-cluster FASTAs into one file
  # per category.
  input {
    Array[File] reads1
    Array[File] reads2
    Array[String] samplenames
    Array[File] assembly_archives
    File genomad_db
    String collection_name
    String? vamb_arguments
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/plasmaag:1.0.1"
    Int cpu = 16
    Int memory = 256
    Int disk_size = 750
  }
  command <<<
    set -euo pipefail
    shopt -s nullglob

    READS1=( ~{sep=' ' reads1} )
    READS2=( ~{sep=' ' reads2} )
    NAMES=( ~{sep=' ' samplenames} )
    ARCHIVES=( ~{sep=' ' assembly_archives} )

    # Extract geNomad database
    mkdir -p genomad_db
    tar -xzvf ~{genomad_db} -C genomad_db --strip-components=1

    # Extract each per-sample assembly archive into assemblies/<samplename>/
    mkdir -p assemblies
    for i in "${!NAMES[@]}"; do
      name="${NAMES[$i]}"
      archive="${ARCHIVES[$i]}"
      mkdir -p "assemblies/${name}"
      tar -xzvf "${archive}" -C "assemblies/${name}" --strip-components=1
    done

    # Build the PlasMAAG TSV: header + one data row per sample
    printf "read1\tread2\tassembly_dir\n" > samples.tsv
    for i in "${!NAMES[@]}"; do
      printf "%s\t%s\t%s\n" \
        "${READS1[$i]}" \
        "${READS2[$i]}" \
        "$(pwd)/assemblies/${NAMES[$i]}" \
        >> samples.tsv
    done

    # Capture version (best-effort; PlasMAAG --version may not exist)
    PlasMAAG --version 2>&1 | head -1 | tee VERSION || echo "unknown" > VERSION

    PlasMAAG \
        --reads_and_assembly_dir samples.tsv \
        --output plasmaag_out \
        --threads ~{cpu} \
        --genomad_db genomad_db \
        ~{"--vamb_arguments '" + vamb_arguments + "'"}

    # PlasMAAG CLI does not propagate snakemake failures (exits 0 even on error).
    # Detect failure by checking for a required output file, then dump all
    # internal PlasMAAG log files to stderr so the actual error is visible on Terra.
    if [ ! -f "plasmaag_out/results/candidate_plasmids.tsv" ]; then
      echo "ERROR: PlasMAAG did not produce expected outputs. Dumping internal logs:" >&2
      for log_file in plasmaag_out/log/*; do
        echo "=== ${log_file} ===" >&2
        cat "${log_file}" >&2 || true
      done
      exit 1
    fi

    # Concatenate per-cluster FASTAs into one file per category.
    # Use nullglob so empty result dirs produce empty FASTAs instead of failing.
    plasmid_files=( plasmaag_out/results/candidate_plasmids/*.fna )
    chrom_files=( plasmaag_out/results/candidate_genomes/*.fna )
    virus_files=( plasmaag_out/results/candidate_viruses/*.fna )

    : > ~{collection_name}_candidate_plasmids.fasta
    if [ ${#plasmid_files[@]} -gt 0 ]; then
      cat "${plasmid_files[@]}" > ~{collection_name}_candidate_plasmids.fasta
    fi

    : > ~{collection_name}_candidate_chromosomes.fasta
    if [ ${#chrom_files[@]} -gt 0 ]; then
      cat "${chrom_files[@]}" > ~{collection_name}_candidate_chromosomes.fasta
    fi

    : > ~{collection_name}_candidate_virus.fasta
    if [ ${#virus_files[@]} -gt 0 ]; then
      cat "${virus_files[@]}" > ~{collection_name}_candidate_virus.fasta
    fi
  >>>
  output {
    File candidate_plasmids_fasta = "~{collection_name}_candidate_plasmids.fasta"
    File candidate_chromosomes_fasta = "~{collection_name}_candidate_chromosomes.fasta"
    File candidate_virus_fasta = "~{collection_name}_candidate_virus.fasta"

    File candidate_plasmids_tsv = "plasmaag_out/results/candidate_plasmids.tsv"
    File candidate_genomes_tsv = "plasmaag_out/results/candidate_genomes.tsv"
    File candidate_virus_tsv = "plasmaag_out/results/candidate_virus.tsv"
    File plasmid_scores_tsv = "plasmaag_out/results/plasmid_scores.tsv"
    File virus_organism_scores_tsv = "plasmaag_out/results/virus_organism_scores.tsv"

    String plasmaag_version = read_string("VERSION")
    String plasmaag_docker = "~{docker}"
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: cpu
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
    maxRetries: 0
  }
}
