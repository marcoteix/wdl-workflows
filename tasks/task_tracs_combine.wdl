version 1.0

# Combines the per-sample TRACS alignments into one multiple sequence alignment (MSA) per
# reference. Only the MSAs of references found in two or more samples are kept, as SNP
# distances need at least two sequences.
#   TRACS documentation: https://gthlab.au/tracs/#/README
#   TRACS combine source: https://github.com/gtonkinhill/tracs/blob/main/tracs/combine.py

task tracs_combine {
  input {
    # Alignment archives created with tracs_align, one per sample
    Array[File] alignment_archives
    Int cpu = 2
    Int memory = 8
    Int disk_size = 50
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
  }
  command <<<
    set -euo pipefail

    # Log the date and TRACS version
    date
    tracs --version | tee VERSION

    # ---------------------------------------------------------------------------------
    # Unpack the per-sample alignments
    # Each archive holds a directory named after its sample. TRACS combine names the
    # sequences in the MSAs after these directories.
    # ---------------------------------------------------------------------------------
    mkdir alignments
    for archive in ~{sep=' ' alignment_archives}; do
      tar -xzf "${archive}" -C alignments
    done

    # List the sample directories, one per line. TRACS combine reads a single -i argument
    # as such a list, so this works for any number of samples.
    find alignments -mindepth 1 -maxdepth 1 -type d | sort > sample_directories.txt
    echo "Combining the alignments of $(wc -l < sample_directories.txt) sample(s)."

    # ---------------------------------------------------------------------------------
    # Combine the alignments into one MSA per reference (<reference>_combined.fasta.gz)
    # ---------------------------------------------------------------------------------
    tracs combine -i sample_directories.txt -o combined -t ~{cpu}

    # ---------------------------------------------------------------------------------
    # Keep the MSAs of references found in two or more samples
    # ---------------------------------------------------------------------------------
    shopt -s nullglob
    mkdir shared
    for msa in combined/*_combined.fasta.gz; do
      n_sequences=$(zcat "${msa}" | grep -c "^>" || true)
      if (( n_sequences >= 2 )); then
        mv "${msa}" shared/
      else
        echo "Skipping reference $(basename "${msa}" _combined.fasta.gz): found in only one sample."
      fi
    done
    echo "$(find shared -name "*_combined.fasta.gz" | wc -l) reference(s) found in two or more samples."
  >>>
  output {
    # One MSA (gzipped FASTA) per reference found in two or more samples, named
    # <reference>_combined.fasta.gz. Sequences are named after the samples.
    Array[File] combined_msas = glob("shared/*_combined.fasta.gz")
    # Software version and Docker image
    String tracs_version = read_string("VERSION")
    String tracs_docker = docker
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
