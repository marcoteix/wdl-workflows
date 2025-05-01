version 1.0

task find_straingst_fasta {
  input {
    String query_strain
    Array[File] straingst_strains
    String fasta_location
    String fasta_extension = ".fa"
    Int disk_size = 8
  }
  command <<<

    python3 <<CODE
    import pandas as pd
    from pathlib import Path

    # Read TSV with strains

    straingst_strains = "~{sep=' ' straingst_strains}" \
      .split(" ")
    query = "~{query_strain}"

    straingst = pd.concat(
      [
        pd.read_csv(
          x,
          sep = "\t",
          index_col = 0
        )
        for x in straingst_strains
      ]
    )

    # Make sure the query is one of the detected strains
    if not query in straingst.strain.values:
      raise ValueError(
          f"The query strain ({query}) is not one of the strains detected by StrainGST."
      )

    if len(straingst) == 1:
        print(
            "StrainGST only detected one strain in the sample. CleanSweep may behave unexpectedly."
        )

    # Find the FASTA for each strain

    extension = "~{fasta_extension}"
    location = "~{fasta_location}"

    location = location.removesuffix("/")

    straingst = straingst.assign(
      fasta = straingst.strain \
        .apply(
            lambda x: location + "/" + x + extension
        )
    )

    straingst = straingst.drop_duplicates(
      subset = "strain"
    )

    with open("query.txt", "w") as file:
      file.write(
        straingst.loc[
          straingst.strain.eq(query),
          "fasta"
        ].iloc[0]
      )

    with open("background.txt", "w") as file:
      file.write(
        "\n".join(
          straingst.loc[
            straingst.strain.ne(query),
            "fasta"
          ].values
        )
      )
    
    with open("all.txt", "w") as file:
      file.write(
        "\n".join(
          straingst["fasta"].values
        )
      )

    with open("names.txt", "w") as file:
      file.write(
        "\n".join(
          straingst["strain"].values
        )
      )

    CODE
  >>>
  output {
    File query_fasta = read_string("query.txt")
    Array[File] background_fasta = read_lines("background.txt")
    Array[File] all_strains_fasta = read_lines("all.txt")
    Array[String] strain_names = read_lines("names.txt")
  }
  runtime {
    docker: "us-docker.pkg.dev/general-theiagen/theiagen/terra-tools:2023-03-16"
    memory: "4 GB"
    cpu: 1
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    maxRetries: 1
  }
}