version 1.0

import "../tasks/task_concat_files.wdl" as concat_task

workflow concatenate {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Concatenates files from multiple samples into a single file. Allows appending to an existing file."
    }
    input {
        Array[File] files
        File? base_file
        String extension = "txt"
        Int memory = 4
    }
    call concat_task.concat_files {
        input:
            files = files,
            base_file = base_file,
            extension = extension,
            memory = memory
    }
    output {
        File concatenated_file = concat_files.concatenated
    }
}