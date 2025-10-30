version 1.0

import "../tasks/task_plasmer.wdl" as plasmer_task 
import "../tasks/task_mob_typer.wdl" as mob_typer_task 


workflow plasmer_wf {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Annotates plasmid contigs with Plasmer and types them with MOB-typer."
    }
    input {
        File assembly_fasta
        File plasmer_database 
        String samplename
        Int plasmer_min_length = 500
        Int plasmer_max_length = 0
    }
    call plasmer_task.plasmer {
        input:
            assembly_fasta = assembly_fasta,
            plasmer_database = plasmer_database,
            samplename = samplename,
            min_length = plasmer_min_length,
            length = plasmer_max_length
    }
    call mob_typer_task.mob_typer {
        input:
            plasmid_fasta = plasmer.plasmer_plasmid_fasta,
            samplename = samplename
    }
    output {
        # Plasmer output
        File plasmer_probabilities = plasmer.plasmer_probabilities
        File plasmer_classes = plasmer.plasmer_classes
        File plasmer_plasmid_taxa = plasmer.plasmer_plasmid_taxa 
        File plasmer_plasmid_fasta = plasmer.plasmer_plasmid_fasta
        String plasmer_version = plasmer.plasmer_version 
        String plasmer_docker = plasmer.plasmer_docker
        # MOB-typer output
        File mob_typer_results = mob_typer.mob_typer_results
        String mob_typer_version = mob_typer.mob_typer_version
        String mob_typer_docker = mob_typer.mob_typer_docker
    }
}