version 1.0

task concat_fastas {
    input {
        Array[File] files 
        Array[String] sample_names
        Int memory = 4
    }
    command <<<

    files=( ~{sep=' ' files} )
    sample_names=( ~{sep=' ' sample_names} )

    touch "concatenated.fa"

    for i in ${!files[@]}; do

        file=${files[i]}
        sample_name=${sample_names[i]}

        cat $file | sed "s/>/>"$sample_name"_/g" >> "concatenated.fa"
        printf "\n" >> "concatenated.fa"

    done

    >>>
    output {
        File concatenated = "concatenated.fa"
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