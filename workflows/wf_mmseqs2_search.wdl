version 1.0

import "../tasks/task_mmseqs2_search.wdl" as mmseqs2_search_task

workflow mmseqs2_search {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Many to many sequence search with MMseqs2."
    }
    input {
        String samplename
        File query
        File reference
        String reference_name
    }
    call mmseqs2_search_task.mmseqs2_search {
        input:
            query = query,
            reference = reference,
            samplename = samplename,
            reference_name = reference_name
    }
    output {
        File mmseqs2_alignment = mmseqs2_search.mmseqs2_alignment
    }
}