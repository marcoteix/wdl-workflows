version 1.0

task concat_files {
    input {
        Array[File] files 
        File? base_file
        String extension = "txt"
        Int memory = 4
    }
    command <<<

    touch concatenated.~{extension}

    if [ -f ~{base_file} ]; then 

        cat ~{base_file} >> concatenated.~{extension}

    fi

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