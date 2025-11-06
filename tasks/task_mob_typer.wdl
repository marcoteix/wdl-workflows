version 1.0

task mob_typer {
  # Annotates plasmid contigs with Plasmer
  input {
    File plasmid_fasta
    String samplename
    String mob_typer_options = ""
    String docker = "kbessonov/mob_suite:3.0.3"
    Int disk_size = 128
    Int memory = 32
    Int cpu = 4
  }
  command <<<

    # Get MOB-typer version
    mob_typer --version | cut -d" " -f2 | tee VERSION

    # Run MOB-typer
    mob_typer \
        --multi \
        --infile ~{plasmid_fasta} \
        --out_file ~{samplename}_mobtyper.txt \
        --num_threads ~{cpu} \
        ~{mob_typer_options}

  >>>
  output {
    File mob_typer_results = "~{samplename}_mobtyper.txt"
    String mob_typer_version = read_string("VERSION")
    String mob_typer_docker = "~{docker}"
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: cpu
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    maxRetries: 1
  }
}