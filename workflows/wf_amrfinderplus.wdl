version 1.0

import "../tasks/task_amrfinderplus.wdl" as amrfinderplus_task

workflow amrfinderplus {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "AMR gene detection with AMRFinderPlus."
    }
    input {
        File assembly
        String samplename
        String? organism 
        Float? minid
        Float? mincov
        Boolean detailed_drug_class = false
        Int cpu = 4
        Int memory = 16
        String docker = "us-docker.pkg.dev/general-theiagen/staphb/ncbi-amrfinderplus:3.11.11-2023-04-17.1"
        Int disk_size = 100     
    }
    call amrfinderplus_task.amrfinderplus {
        input:
            samplename = samplename,
            assembly = assembly,
            organism = organism,
            minid = minid,
            mincov = mincov,
            detailed_drug_class = detailed_drug_class,
            docker = docker,
            cpu = cpu,
            memory = memory,
            disk_size = disk_size
    }
    output {
        File amrfinderplus_all_report = amrfinderplus.amrfinderplus_all_report
        File amrfinderplus_amr_report = amrfinderplus.amrfinderplus_amr_report
        File amrfinderplus_stress_report = amrfinderplus.amrfinderplus_stress_report
        File amrfinderplus_virulence_report = amrfinderplus.amrfinderplus_virulence_report
        File amrfinderplus_amr_core_genes = amrfinderplus.amrfinderplus_amr_core_genes
        File amrfinderplus_amr_plus_genes = amrfinderplus.amrfinderplus_amr_plus_genes
        File amrfinderplus_stress_genes = amrfinderplus.amrfinderplus_stress_genes
        File amrfinderplus_virulence_genes = amrfinderplus.amrfinderplus_virulence_genes
        File amrfinderplus_amr_classes = amrfinderplus.amrfinderplus_amr_classes
        File amrfinderplus_amr_subclasses = amrfinderplus.amrfinderplus_amr_subclasses
        String amrfinderplus_version = amrfinderplus.amrfinderplus_version
        String amrfinderplus_db_version = amrfinderplus.amrfinderplus_db_version
    }
}