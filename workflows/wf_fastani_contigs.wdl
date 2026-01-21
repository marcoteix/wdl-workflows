version 1.0

import "../tasks/task_concat_fastas.wdl" as concat_fastas_task
import "../tasks/task_fastani.wdl" as fastani_task

workflow fastani_contigs {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Calculates the ANI between contigs in a set of samples with fastANI."
    }
    input {
        Array[File] fastas
        Array[String] sample_names
        # FastANI options
        Int kmer_size = 16
        Int fragment_length = 3000
        Float min_fraction = 0.2
        Float max_ratio_difference = 10.0
    }
    call concat_fastas_task.concat_fastas {
        input:
            files = fastas,
            sample_names = sample_names
    }
    call fastani_task.fastani {
        input:
            reference = concat_fastas.concatenated,
            query = concat_fastas.concatenated,
            kmer_size = kmer_size,
            fragment_length = fragment_length,
            min_fraction = min_fraction,
            max_ratio_difference = max_ratio_difference
    }
    output {
        String fastani_version = fastani.fastani_version
        File fastani_results = fastani.fastani_results
    }
}