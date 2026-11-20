version 1.0

# Merges the StrainGST strain reports (*.strains.tsv) of one sample into a single report,
# to be given to the straingst_strains input of the TRACS workflow (workflows/wf_tracs.wdl).
# A sample can have several reports (e.g. one per StrainGST database). When the TRACS
# workflow runs on a Terra set, Terra flattens the per-sample lists of reports into one
# list, losing which report belongs to which sample; merging the reports of each sample
# beforehand keeps them together.
#   StrainGST documentation: https://strainge.readthedocs.io/en/latest/straingst.html
#
# The merged report has the header line once, followed by the strain rows of every
# report, unchanged and in the order the reports were given.

task tracs_merge_straingst_reports {
  input {
    # Sample name, used to name the merged report
    String samplename
    # StrainGST strain reports of the sample
    Array[File] straingst_strains
    Int disk_size = 8
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
  }
  command <<<
    set -euo pipefail

    reports=( ~{sep=' ' straingst_strains} )
    if (( ${#reports[@]} == 0 )); then
      echo "ERROR: no StrainGST reports were given for ~{samplename}." >&2
      exit 1
    fi

    # ---------------------------------------------------------------------------------
    # Every report must have the same columns, otherwise their rows cannot be combined
    # ---------------------------------------------------------------------------------
    header=$(head -n 1 "${reports[0]}")
    for report in "${reports[@]}"; do
      if [[ "$(head -n 1 "${report}")" != "${header}" ]]; then
        echo "ERROR: ${report} has a different header from ${reports[0]}." >&2
        exit 1
      fi
    done

    # ---------------------------------------------------------------------------------
    # Write the header once, then the strain rows of every report (blank lines dropped)
    # ---------------------------------------------------------------------------------
    {
      echo "${header}"
      for report in "${reports[@]}"; do
        tail -n +2 "${report}" | grep -v '^[[:space:]]*$' || true
      done
    } > ~{samplename}.strains.tsv

    echo "Merged ${#reports[@]} report(s) of ~{samplename}: $(( $(wc -l < ~{samplename}.strains.tsv) - 1 )) strain row(s)."
  >>>
  output {
    # Merged StrainGST report of the sample
    File merged_straingst_strains = "~{samplename}.strains.tsv"
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
