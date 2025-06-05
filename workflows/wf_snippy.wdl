version 1.0

import "../tasks/task_snippy_variants.wdl" as snippy_variants_task 

workflow snippy {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Calls variants with Snippy, supporting contigs as input."
    }
    input {
        String samplename
        File? reads1 
        File? reads2
        File? contigs
        File reference_genome
        String docker = "us-docker.pkg.dev/general-theiagen/staphb/snippy:4.6.0"
        Int cpus = 8
        Int memory = 32
        Int? map_qual
        Int? base_quality
        Int? min_coverage
        Float? min_frac
        Int? min_quality
        Int? maxsoft
    }
    call snippy_variants_task.snippy_variants {
        input:
            reference_genome_file = reference_genome,
            read1 = reads1,
            read2 = reads2,
            contigs = contigs,
            samplename = samplename,
            docker = docker,
            cpus = cpus,
            memory = memory,
            map_qual = map_qual,
            base_quality = base_quality,
            min_coverage = min_coverage,
            min_frac = min_frac,
            min_quality = min_quality,
            maxsoft = maxsoft
    }
    output {
        File snippy_variants_outdir_tarball = snippy_variants.snippy_variants_outdir_tarball
        File snippy_variants_vcf = snippy_variants.snippy_variants_vcf
        File snippy_variants_results = snippy_variants.snippy_variants_results
        String snippy_variants_version = snippy_variants.snippy_variants_version
        String snippy_variants_docker = snippy_variants.snippy_variants_docker
        Array[File] snippy_variants_outputs = snippy_variants.snippy_variants_outputs
        File snippy_variants_bam = snippy_variants.snippy_variants_bam
        File snippy_variants_bai = snippy_variants.snippy_variants_bai
        File snippy_variants_summary = snippy_variants.snippy_variants_summary
    }
}