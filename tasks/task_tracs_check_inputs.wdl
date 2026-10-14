version 1.0

# Checks the inputs of the TRACS workflow (workflows/wf_tracs.wdl) before any data is
# processed, so that configuration mistakes fail early with a clear error message.
# Only the number of entries of each per-sample input is passed in (not the files
# themselves), so no reads or FASTAs are copied to this task.

task tracs_check_inputs {
  input {
    # Sample names, one per sample
    Array[String] samplenames
    # Number of forward and reverse read files
    Int n_reads1
    Int n_reads2
    # Number of per-sample reference FASTA lists (undefined if reference_fastas was not given)
    Int? n_reference_fastas
    # Number of per-sample StrainGST report lists (undefined if straingst_strains was not given)
    Int? n_straingst_strains
    # Whether the location of the StrainGST reference FASTAs was given
    Boolean straingst_fasta_location_given
    Int disk_size = 10
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
  }
  # Sample names written to a file, one per line
  File samplenames_file = write_lines(samplenames)
  command <<<
    set -euo pipefail

    # Every check runs before failing, so that all problems are reported at once
    n_errors=0
    report_error() {
      echo "ERROR: $1" >&2
      n_errors=$((n_errors + 1))
    }

    n_samples=~{length(samplenames)}
    # Empty if the input was not given
    n_reference_fastas="~{default='' n_reference_fastas}"
    n_straingst_strains="~{default='' n_straingst_strains}"

    # ---------------------------------------------------------------------------------
    # References: exactly one of reference_fastas or straingst_strains must be given
    # ---------------------------------------------------------------------------------
    if [[ -n "${n_reference_fastas}" && -n "${n_straingst_strains}" ]]; then
      report_error "Both reference_fastas and straingst_strains were given. Provide only one of them."
    elif [[ -z "${n_reference_fastas}" && -z "${n_straingst_strains}" ]]; then
      report_error "Neither reference_fastas nor straingst_strains was given. Provide one of them."
    fi

    # StrainGST reports only name the strains, so the location of their FASTAs is needed
    if [[ -n "${n_straingst_strains}" && "~{straingst_fasta_location_given}" != "true" ]]; then
      report_error "straingst_fasta_location is required when straingst_strains is given."
    fi

    # ---------------------------------------------------------------------------------
    # Per-sample inputs must have one entry per sample
    # ---------------------------------------------------------------------------------
    if (( n_samples == 0 )); then
      report_error "samplenames is empty."
    fi

    # Arguments: input name, number of entries (empty if the input was not given)
    check_n_entries() {
      if [[ -n "$2" && "$2" -ne "${n_samples}" ]]; then
        report_error "$1 has $2 entries, but samplenames has ${n_samples}."
      fi
    }
    check_n_entries reads1 ~{n_reads1}
    check_n_entries reads2 ~{n_reads2}
    check_n_entries reference_fastas "${n_reference_fastas}"
    check_n_entries straingst_strains "${n_straingst_strains}"

    # ---------------------------------------------------------------------------------
    # Sample names
    # TRACS names directories and MSA sequences after the samples, and TRACS distance
    # cuts sequence names at the first whitespace, so sample names must be unique,
    # non-empty, and contain no whitespace or "/".
    # ---------------------------------------------------------------------------------
    while IFS= read -r name || [[ -n "${name}" ]]; do
      if [[ -z "${name}" ]]; then
        report_error "Sample names cannot be empty."
      elif [[ "${name}" =~ [[:space:]/] ]]; then
        report_error "Sample name '${name}' contains whitespace or '/'."
      fi
    done < ~{samplenames_file}

    duplicated_names=$(sort ~{samplenames_file} | uniq -d | paste -sd ',' -)
    if [[ -n "${duplicated_names}" ]]; then
      report_error "Sample names must be unique. Duplicated names: ${duplicated_names}"
    fi

    if (( n_errors > 0 )); then
      echo "Found ${n_errors} problem(s) with the workflow inputs." >&2
      exit 1
    fi
    echo "Inputs are valid: ${n_samples} samples."
  >>>
  output {
    # Number of samples; only available if every check passed
    Int n_samples = length(samplenames)
  }
  runtime {
    docker: docker
    memory: "2 GB"
    cpu: 1
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
  }
}
