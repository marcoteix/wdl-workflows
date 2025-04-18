version 1.0

# Given a set of FASTA files, builds an mSWEEP clusters file placing
# each FASTA in its own cluster

task fastas_to_msweep_clusters {
  input {
    Array[String] fastas
    String? base_fasta
    String? base_directory
  }
  command <<<

    python3 <<CODE
    import pandas as pd
    from pathlib import Path

    base_directory = "~{base_directory}"
    base_fasta = "~{base_fasta}"
    fastas = "~{sep=' ' fastas}".split(" ")

    # Check if base_fasta exists. Add to list of FASTAs
    if len(base_fasta):
        fastas += [base_fasta]

    clusters = []

    for n, fasta in enumerate(fastas):

        # Extract file name
        cluster_name = Path(fasta).name \
            .removesuffix(".gz") \
            .removesuffix(".fasta") \
            .removesuffix(".fa")

        clusters.append(
            [
                n,
                cluster_name,
                (
                    Path(base_directory).join(Path(fasta).name)
                    if len(base_directory)
                    else fasta
                )
            ]
        )

    # Convert to DataFrame
    clusters = pd.DataFrame(
        clusters,
        columns = [
            "id",
            "cluster",
            "assembly"
        ]
    ).set_index("id")

    # Write file
    clusters.to_csv(
        "msweep.clusters.txt",
        sep = "\t"
    )
    CODE
  >>>
  output {
    File clusters = "msweep.clusters.txt"
  }
  runtime {
    docker: "us-docker.pkg.dev/general-theiagen/theiagen/terra-tools:2023-03-16"
    memory: "4 GB"
    cpu: 1
    disks:  "local-disk 10 SSD"
    disk: "10 GB" # TES
    preemptible: 0
    maxRetries: 1
  }
}