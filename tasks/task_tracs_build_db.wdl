version 1.0

# Builds a TRACS reference database for one sample from a set of reference genome FASTAs.
# The database is a zip file with a sourmash index of the references and a copy of their
# sequences. TRACS align uses it to find which references are present in the sample's reads.
#   TRACS documentation: https://gthlab.au/tracs/#/database

task tracs_build_db {
  input {
    # Sample name, used as the prefix of the database file
    String samplename
    # Reference genome FASTAs (optionally gzipped), one per reference. Each reference is
    # named after its file without the .gz and FASTA extensions, e.g.
    # Esch_coli_H10407.fa.gz -> Esch_coli_H10407. When samples are combined, references
    # with the same name in different samples are treated as the same reference.
    Array[File] reference_fastas
    # TRACS build-db runs on a single thread
    Int memory = 8
    Int disk_size = 50
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
  }
  command <<<
    set -euo pipefail

    # Log the date and TRACS version
    date
    tracs --version

    # ---------------------------------------------------------------------------------
    # List the references as "<reference name>,<FASTA path>", one per line
    # TRACS build-db reads a single -i argument as such a list, so this works for any
    # number of references (two or more -i arguments would be read as FASTAs instead).
    # ---------------------------------------------------------------------------------
    for fasta in ~{sep=' ' reference_fastas}; do
      name=$(basename "${fasta}")
      name=${name%.gz}
      case "${name}" in
        *.fasta|*.fna|*.fa|*.fas) name=${name%.*} ;;
      esac
      echo "${name},${fasta}" >> reference_list.csv
    done

    # References are identified by name, so names must be unique
    duplicated_names=$(cut -d ',' -f 1 reference_list.csv | sort | uniq -d | paste -sd ',' -)
    if [[ -n "${duplicated_names}" ]]; then
      echo "ERROR: more than one reference FASTA of ~{samplename} has the name: ${duplicated_names}" >&2
      exit 1
    fi

    echo "References in the database of ~{samplename}:"
    cat reference_list.csv

    # ---------------------------------------------------------------------------------
    # Build the database
    # TRACS adds the .zip extension to the output name
    # ---------------------------------------------------------------------------------
    tracs build-db -i reference_list.csv -o ~{samplename}_tracs_db
  >>>
  output {
    # TRACS database of the sample
    File tracs_database = "~{samplename}_tracs_db.zip"
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: 1
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
  }
}
