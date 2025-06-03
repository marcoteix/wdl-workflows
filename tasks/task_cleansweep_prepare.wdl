version 1.0

task cleansweep_prepare {
  input {
    String samplename
    File query_reference
    Array[File] background_references
    Float max_identity = 0.95
    Int min_length = 150
    String docker = "marcoteix/cleansweep:main"
    Int disk_size = 8
    Int memory = 16
  }
  command <<<

    # Unzip references if needed
    background=( ~{sep=' ' background_references} )

    for i in ${!background[@]}; do

        fasta=${background[i]}

        if [[ "$fasta" == *".gz" ]]; then
            echo "Unzipping $fasta..."
            background[i]=${fasta%.gz}
            gzip -d $fasta
        fi    
        
    done

    query="~{query_reference}"
    if [[ "$query" == *".gz" ]]; then
            echo "Unzipping $query..."
            query=${query%.gz}
            gzip -d $query
    fi 
    
    echo "Preparing reference with CleanSweep prepare..."

    cleansweep prepare \
        $query \
        --background ${fastas[@]} \
        --min-identity ~{max_identity} \
        --min-length ~{min_length} \
        --output ~{samplename} \
        --verbosity 4

    # Get CleanSweep version
    cleansweep --version | sed "s/CleanSweep//" >> VERSION

    echo Done!

  >>>
  output {
    File cleansweep_reference_fasta = "~{samplename}/cleansweep.reference.fa"
    File cleansweep_prepare_swp = "~{samplename}/cleansweep.prepare.swp"
    String cleansweep_version = read_string("VERSION")
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: 1
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    maxRetries: 1
  }
}