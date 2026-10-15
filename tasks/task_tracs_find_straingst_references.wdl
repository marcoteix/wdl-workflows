version 1.0

# Lists the reference FASTAs of every strain that StrainGST detected in a sample, so that
# they can be used to build the sample's TRACS database.
# Adapted from tasks/task_cleansweep_find_straingst_references.wdl, but without a query
# strain: the FASTAs of all detected strains are returned.
#   StrainGST documentation: https://strainge.readthedocs.io/en/latest/straingst.html

task tracs_find_straingst_references {
  input {
    # StrainGST strain reports (*.strains.tsv) of one sample. A sample may have several
    # reports; the strains detected in all of them are combined.
    Array[File] straingst_strains
    # Location (e.g. gs://bucket/path) of the StrainGST reference FASTAs. The FASTA of each
    # strain must be at <fasta_location>/<strain name><fasta_extension>.
    String fasta_location
    String fasta_extension = ".fa"
    Int disk_size = 8
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
  }
  command <<<
    set -euo pipefail

    python3 <<'CODE'
    import pandas as pd

    # StrainGST reports of this sample
    reports = "~{sep=' ' straingst_strains}".split()

    # Combine the strains detected in all reports. Each report has one row per detected
    # strain, with the strain name in the "strain" column. Reports concatenated with
    # their headers repeat the header line, which pandas reads as a strain named
    # "strain"; those rows are dropped (blank lines are already skipped by pandas).
    strains = []
    for report in reports:
        straingst = pd.read_csv(report, sep="\t", index_col=0)
        detected = straingst["strain"].dropna().astype(str)
        strains.extend(detected[detected != "strain"].tolist())

    # A strain detected in more than one report only needs to be in the database once
    strains = list(dict.fromkeys(strains))

    if len(strains) == 0:
        print("WARNING: StrainGST detected no strains in this sample. The sample will be skipped.")
    else:
        print(f"StrainGST detected {len(strains)} strain(s): {', '.join(strains)}")

    # Path to the reference FASTA of each strain
    location = "~{fasta_location}".rstrip("/")
    extension = "~{fasta_extension}"
    fastas = [f"{location}/{strain}{extension}" for strain in strains]

    with open("reference_fastas.txt", "w") as file:
        file.write("\n".join(fastas))
    CODE
  >>>
  output {
    # Reference FASTAs of the detected strains (empty if StrainGST detected none)
    Array[File] reference_fastas = read_lines("reference_fastas.txt")
  }
  runtime {
    docker: docker
    memory: "4 GB"
    cpu: 1
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
  }
}
