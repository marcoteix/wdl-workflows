version 1.0

import "../tasks/task_bakta.wdl" as bakta_task

workflow bakta {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Bacterial genome annotation with Bakta."
    }
    input {
        File assembly
        File bakta_db = "gs://theiagen-public-resources-rp/reference_data/databases/bakta/bakta_db_full_2024-01-23.tar.gz"
        String samplename
        Int cpu = 8
        Int memory = 16
        String docker = "us-docker.pkg.dev/general-theiagen/biocontainers/bakta:1.5.1--pyhdfd78af_0"
        Int disk_size = 100
        Boolean proteins = false
        Boolean compliant = false
        File? prodigal_tf
        String? bakta_opts        
    }
    call bakta_task.bakta {
        input:
            samplename = samplename,
            assembly = assembly,
            bakta_db = bakta_db,
            proteins = proteins,
            compliant = compliant,
            prodigal_tf = prodigal_tf,
            bakta_opts = bakta_opts,
            docker = docker,
            cpu = cpu,
            memory = memory,
            disk_size = disk_size
    }
    output {
        File bakta_embl = bakta.bakta_embl
        File bakta_faa = bakta.bakta_faa
        File bakta_ffn = bakta.bakta_ffn
        File bakta_fna = bakta.bakta_fna
        File bakta_gbff = bakta.bakta_gbff
        File bakta_gff3 = bakta.bakta_gff3
        File bakta_hypotheticals_faa = bakta.bakta_hypotheticals_faa
        File bakta_hypotheticals_tsv = bakta.bakta_hypotheticals_tsv
        File bakta_tsv = bakta.bakta_tsv
        File bakta_txt = bakta.bakta_txt
        String bakta_version = bakta.bakta_version
        String bakta_database = bakta.bakta_database
    }
}