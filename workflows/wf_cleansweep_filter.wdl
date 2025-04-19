version 1.0

import "../tasks/task_cleansweep_filter.wdl" as cleansweep_filter_task

workflow cleansweep_filter {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Strain-specific variant calling from plate swipe data with CleanSweep."
    }
    input {
        String samplename
        File variants
        File cleansweep_prepare_swp
        # Cleansweep filter options
        Int cleansweep_min_depth = 10
        Int cleansweep_min_alt_bc = 10
        Int cleansweep_min_ref_bc = 0
        Int cleansweep_num_variants_estimator = 200
        Int cleansweep_num_variants_coverage = 100000
        Float overdispersion_bias = 1
        Float cleansweep_max_overdispersion = 0.70
        Int cleansweep_random_state = 23
        Int cleansweep_num_chains = 5
        Int cleansweep_num_draws = 100000
        Int cleansweep_num_burnin = 1000
        Int cleansweep_cpu = 5
        String cleansweep_docker = "marcoteix/cleansweep:main"
    }
    call cleansweep_filter_task.cleansweep_filter {
        input:
            samplename = samplename,
            variants_vcf = variants,
            cleansweep_prepare_swp = cleansweep_prepare_swp,
            min_depth = cleansweep_min_depth,
            min_alt_bc = cleansweep_min_alt_bc,
            min_ref_bc = cleansweep_min_ref_bc,
            num_variants_estimator = cleansweep_num_variants_estimator,
            num_variants_coverage = cleansweep_num_variants_coverage,
            overdispersion_bias = overdispersion_bias,
            max_overdispersion = cleansweep_max_overdispersion,
            random_state = cleansweep_random_state,
            num_chains = cleansweep_num_chains,
            num_draws = cleansweep_num_draws,
            num_burnin = cleansweep_num_burnin,
            docker = cleansweep_docker,
            cpu = cleansweep_cpu
    }
    output {
        File cleansweep_variants = cleansweep_filter.cleansweep_variants
        File cleansweep_filter_swp = cleansweep_filter.cleansweep_filter
        File cleansweep_report = cleansweep_filter.cleansweep_report
        File cleansweep_allele_depths_plot = cleansweep_filter.cleansweep_allele_depths_plot
        File cleansweep_query_depths_plot = cleansweep_filter.cleansweep_query_depths_plot
    }
}