version 1.0

task mmseqs2_createdb {
  # Builds an MMseqs2 database from a FASTA file and packages it as a tar
  # archive with layout db/<reference_name>/, matching what
  # task_mmseqs2_search.wdl and task_mmseqs2_assembly_search.wdl expect.
  input {
    File fasta
    String reference_name
    String docker = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/mmseqs2:8cc5ce367b5638c4306c2d7cfc652dd099a4643f"
    Int cpu = 4
    Int memory = 16
    Int disk_size = 50
  }
  command <<<
    set -euo pipefail

    mmseqs version 2>&1 | head -1 | tee VERSION

    mkdir -p db/~{reference_name}
    mmseqs createdb ~{fasta} db/~{reference_name}/~{reference_name}

    tar -czf ~{reference_name}_db.tar.gz db/
  >>>
  output {
    File mmseqs2_database = "~{reference_name}_db.tar.gz"
    String mmseqs2_version = read_string("VERSION")
    String mmseqs2_docker = "~{docker}"
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: cpu
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
    maxRetries: 1
  }
}
