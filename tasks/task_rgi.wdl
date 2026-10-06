version 1.0

# Detects antimicrobial resistance (AMR) genes in short reads by aligning them to the
# Comprehensive Antibiotic Resistance Database (CARD) with the Resistance Gene Identifier
# (RGI) in bwt (read mapping) mode.
#   RGI bwt documentation: https://github.com/arpcard/rgi/blob/master/docs/rgi_bwt.rst
#   CARD data downloads:   https://card.mcmaster.ca/download
#
# Reads are aligned only to CARD's canonical protein homolog models (the RGI bwt default).
# WildCARD (Resistomes & Variants) and the other CARD model types are not used.

task rgi_bwt {
  input {
    # Quality-controlled and trimmed reads (FASTQ, optionally gzipped).
    # Omit read2 for single-end reads.
    File read1
    File? read2
    # Prefix for all output files
    String samplename
    # CARD data archive, as downloaded from https://card.mcmaster.ca/latest/data
    # (e.g. broadstreet-v4.0.1.tar.bz2). Determines the CARD version used.
    File card_data_tarball
    # Read aligner: "kma" (default, recommended by RGI), "bowtie2", or "bwa".
    # The Depth, SNPs, and consensus sequence columns of the allele-level report are
    # only filled in when using KMA; they are left blank with bowtie2 or bwa.
    String aligner = "kma"
    Int cpu = 4
    Int memory = 8
    Int disk_size = 100
    String docker = "quay.io/biocontainers/rgi:6.0.8--pyh05cac1d_0"
  }
  command <<<
    set -euo pipefail

    # Log the date and RGI version
    date
    rgi main --version | tee RGI_VERSION

    # Stop early if the aligner is not one supported by RGI bwt
    case "~{aligner}" in
      kma|bowtie2|bwa) ;;
      *)
        echo "ERROR: unsupported aligner '~{aligner}'. Choose one of: kma, bowtie2, bwa." >&2
        exit 1
        ;;
    esac

    # ---------------------------------------------------------------------------------
    # Prepare the CARD database
    # RGI bwt reads CARD from a local database (./localDB, selected with --local). Besides
    # card.json, it needs CARD's reference sequences for read mapping, which are created
    # by `rgi card_annotation`.
    # ---------------------------------------------------------------------------------

    # Extract card.json from the CARD data archive
    tar -xjf "~{card_data_tarball}" ./card.json

    # Load card.json and record the CARD version
    rgi load --card_json card.json --local
    rgi database --version --local | tee CARD_VERSION
    card_version=$(cat CARD_VERSION)

    # Create the reference FASTA for read mapping (written as card_database_v<version>.fasta)
    # and load it into the local database
    rgi card_annotation --input card.json
    rgi load \
      --card_json card.json \
      --card_annotation "card_database_v${card_version}.fasta" \
      --local

    # ---------------------------------------------------------------------------------
    # Align reads to CARD and report AMR genes
    # ---------------------------------------------------------------------------------

    # --clean removes RGI's temporary files once it finishes
    rgi bwt \
      --read_one ~{read1} \
      ~{'--read_two ' + read2} \
      --aligner ~{aligner} \
      --threads ~{cpu} \
      --output_file ~{samplename} \
      --local \
      --clean

    # RGI can exit with status 0 without writing its reports (e.g. if the database did not
    # load), so make sure every report exists
    for report in allele_mapping_data gene_mapping_data artifacts_mapping_stats overall_mapping_stats reference_mapping_stats; do
      if [[ ! -f "~{samplename}.${report}.txt" ]]; then
        echo "ERROR: RGI did not write ~{samplename}.${report}.txt" >&2
        exit 1
      fi
    done

    # List the unique AMR genes (ARO terms) in the gene-level report, comma-separated.
    # The "ARO Term" column is found by its header name.
    amr_genes=$(awk -F '\t' '
      NR == 1 { for (i = 1; i <= NF; i++) if ($i == "ARO Term") column = i; next }
      { print $column }
    ' "~{samplename}.gene_mapping_data.txt" | sort -u | paste -sd ',' -)

    if [[ -z "${amr_genes}" ]]; then
      amr_genes="No AMR genes detected by RGI"
    fi
    echo "${amr_genes}" > AMR_GENES
  >>>
  output {
    # RGI bwt reports; column descriptions are in the RGI bwt documentation
    # Read mapping results per CARD allele, including read depth (KMA only)
    File rgi_allele_mapping_data = "~{samplename}.allele_mapping_data.txt"
    # Allele results summed per AMR gene
    File rgi_gene_mapping_data = "~{samplename}.gene_mapping_data.txt"
    # Statistics on read mapping artifacts
    File rgi_artifacts_mapping_stats = "~{samplename}.artifacts_mapping_stats.txt"
    # Overall read mapping statistics
    File rgi_overall_mapping_stats = "~{samplename}.overall_mapping_stats.txt"
    # Statistics on the CARD reference sequences that reads mapped to
    File rgi_reference_mapping_stats = "~{samplename}.reference_mapping_stats.txt"

    # Comma-separated list of detected AMR genes (ARO terms)
    String rgi_amr_genes = read_string("AMR_GENES")

    # Software and database versions
    String rgi_version = read_string("RGI_VERSION")
    String card_version = read_string("CARD_VERSION")
    String rgi_docker = docker
  }
  runtime {
    docker: docker
    memory: memory + " GB"
    cpu: cpu
    disks: "local-disk " + disk_size + " SSD"
    disk: disk_size + " GB"
    preemptible: 0
  }
}
