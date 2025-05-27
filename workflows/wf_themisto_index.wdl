version 1.0

import "../tasks/task_themisto.wdl" as themisto_task

workflow make_themisto_index {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Builds a Themisto index from a set of FASTA files."
    }
    input {
        String samplename
        Array[File] references 
        Array[String] references_names
        # Themisto options
        String themisto_docker_image = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/themisto:3.2.2"
        Int themisto_kmer_size = 31
        Int themisto_cpu = 4
        Int themisto_memory = 32
        Int themisto_disk_size = 128
    }
    call themisto_task.themisto_index as themisto {
        input:
            references = references,
            reference_names = references_names,
            samplename = samplename,
            docker = themisto_docker_image,
            kmer_size = themisto_kmer_size,
            cpu = themisto_cpu,
            memory = themisto_memory,
            disk_size = themisto_disk_size
    }
    output {
        # Themisto outputs
        File themisto_index = themisto.themisto_index
        File clustering = themisto.clustering
        String themisto_docker = themisto.themisto_docker
    }
}