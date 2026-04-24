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
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/plasmaag/1.0.1"
    Int cpu = 16
    Int memory = 64
    Int disk_size = 500
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

    # Build the PlasMAAG TSV: read1 read2 assembly_dir (one row per sample)
    : > samples.tsv
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
        --genomad_db genomad_db

    # Concatenate per-cluster FASTAs into one file per category.
    # Use nullglob so empty result dirs produce empty FASTAs instead of failing.
    plasmid_files=( plasmaag_out/results/candidate_plasmids/*.fa plasmaag_out/results/candidate_plasmids/*.fasta )
    chrom_files=( plasmaag_out/results/candidate_genomes/*.fa plasmaag_out/results/candidate_genomes/*.fasta )
    virus_files=( plasmaag_out/results/candidate_virus/*.fa plasmaag_out/results/candidate_virus/*.fasta )

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
    File scores_tsv = "plasmaag_out/results/scores.tsv"

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
