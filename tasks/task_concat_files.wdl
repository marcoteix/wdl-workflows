version 1.0

task concat_files {
    input {
        Array[File] files 
        String extension = "txt"
        Int memory = 4
    }
    command <<<

    touch concatenated.~{extension}

    for file in ~{sep=' ' files}; do 

        echo -e >> concatenated.~{extension}
        cat $file >> concatenated.~{extension}
    
    done

    >>>
    output {
        File concatenated = "concatenated.~{extension}"
    }
    runtime {
        docker: "us-docker.pkg.dev/general-theiagen/theiagen/terra-tools:2023-03-16"
        memory: "~{memory} GB"
        cpu: 1
        disks:  "local-disk 10 SSD"
        disk: "10 GB" # TES
        preemptible: 0
        maxRetries: 1    
    }
}