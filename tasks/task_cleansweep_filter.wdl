version 1.0

task cleansweep_filter {
  input {
    String samplename
    File variants_vcf
    File cleansweep_prepare_swp
    Int min_depth = 10
    Int min_alt_bc = 10
    Int min_ref_bc = 0
    Int num_variants_estimator = 200
    Int num_variants_coverage = 100000
    Float max_overdispersion = 0.7
    Int random_state = 23
    Int num_chains = 5
    Int num_draws = 100000
    Int num_burnin = 1000
    String docker = "marcoteix/cleansweep:main"
    Int mem = 8
    Int cpu = 5
    Int disk_size = 8
  }
  command <<<

    echo "Compressing and indexing VCF..."

    mkdir -p ~{samplename}

    bcftools view \
      ~{variants_vcf} \
      -o ~{samplename}/~{samplename}.pilon.vcf.gz \
      -O z

    bcftools index ~{samplename}/~{samplename}.pilon.vcf.gz

    echo "Filtering variants with CleanSweep..."

    cleansweep filter \
        ~{samplename}/~{samplename}.pilon.vcf.gz \
        ~{cleansweep_prepare_swp} \
        ~{samplename} \
        --min-depth ~{min_depth} \
        --min-alt-bc ~{min_alt_bc} \
        --min-ref-bc ~{min_ref_bc} \
        --downsample ~{num_variants_estimator} \
        --max-overdispersion ~{max_overdispersion} \
        --n-coverage-sites ~{num_variants_coverage} \
        --seed ~{random_state} \
        --n-chains ~{num_chains} \
        --n-draws ~{num_draws} \
        --n-burnin ~{num_burnin} \
        --threads ~{cpu} \
        --verbosity 4

    echo "Running CleanSweep inspect..."

    mkdir -p ~{samplename}/inspect

    cleansweep inspect \
        ~{samplename}/cleansweep.variants.vcf \
        ~{samplename}/inspect \
        -c ~{samplename}/cleansweep.filter.swp \
        --how all \
        -f png \
        -adl -qdl

    echo Done!

  >>>
  output {
    File cleansweep_variants = "~{samplename}/cleansweep.variants.vcf"
    File cleansweep_filter = "~{samplename}/cleansweep.filter.swp"
    File cleansweep_report = "~{samplename}/inspect/cleansweep.info.json"
    File cleansweep_allele_depths_plot = "~{samplename}/inspect/cleansweep.allele_depths.png"
    File cleansweep_query_depths_plot = "~{samplename}/inspect/cleansweep.query_depths.png"
  }
  runtime {
    docker: docker
    memory: mem + " GB"
    cpu: cpu
    disks:  "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB" # TES
    preemptible: 0
    maxRetries: 1
  }
}