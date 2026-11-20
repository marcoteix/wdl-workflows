version 1.0

import "../tasks/task_tracs_merge_straingst_reports.wdl" as tracs_merge_straingst_reports_task

# Merges the StrainGST strain reports of one sample into a single report. Run it on each
# sample (one Terra row at a time) before the TRACS workflow (workflows/wf_tracs.wdl), and
# give the merged reports to the straingst_strains input of the TRACS workflow.

workflow tracs_merge_straingst {
    meta {
        author: "Marco Teixeira"
        email: "mcarvalh@broadinstitute.org"
        description: "Merges the StrainGST strain reports of one sample into one report for the TRACS workflow."
    }
    input {
        # Sample name, used to name the merged report
        String samplename
        # StrainGST strain reports (*.strains.tsv) of the sample
        Array[File] straingst_strains
        String tracs_docker_image = "us-central1-docker.pkg.dev/gcid-bacterial/gcid-bacterial/tracs:latest"
    }
    call tracs_merge_straingst_reports_task.tracs_merge_straingst_reports {
        input:
            samplename = samplename,
            straingst_strains = straingst_strains,
            docker = tracs_docker_image
    }
    output {
        # Merged StrainGST report of the sample (<samplename>.strains.tsv)
        File merged_straingst_strains = tracs_merge_straingst_reports.merged_straingst_strains
    }
}
