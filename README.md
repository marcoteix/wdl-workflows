# wdl-workflows
WDL workflows and tasks for genomic analysis.

## Tasks

### `vcf_to_fasta` · [tasks/vcf_to_fasta.wdl](tasks/vcf_to_fasta.wdl)

Converts a single-sample whole-genome VCF into a FASTA sequence. Uses `bcftools` to split multi-allelic sites, strip indels, and extract per-position genotype calls, then builds the sequence in Python applying IUPAC ambiguity codes for heterozygous or multi-allelic positions. Positions below the minimum depth threshold or with a missing genotype call are written as `N`.

| Input | Type | Default | Description |
|---|---|---|---|
| `vcf` | `File` | — | Input VCF (compressed or uncompressed) |
| `sequence_name` | `String` | — | FASTA header label and output filename stem |
| `min_dp` | `Int` | `10` | Minimum depth; positions below threshold are masked as `N` |
| `docker` | `String` | `marcoteix/cleansweep:heads-main` | |
| `memory` | `Int` | `8` | GB |
| `disk_size` | `Int` | `16` | GB |

| Output | Type | Description |
|---|---|---|
| `fasta` | `File` | FASTA file named `<sequence_name>.fasta` |

---

### `fastas_to_msa` · [tasks/task_fastas_to_msa.wdl](tasks/task_fastas_to_msa.wdl)

Assembles a multisequence alignment (MSA) from a set of FASTA files and a reference sequence. Each input FASTA can contain a single sequence or be an existing MSA (multiple sequences). All sequences must share the same length as the reference; the task exits with an error otherwise. Samples with more than `max_missing_pct`% N bases are excluded from the output; the reference is always retained.

| Input | Type | Default | Description |
|---|---|---|---|
| `fastas` | `Array[File]` | — | Input FASTA files (single-sequence or pre-built MSA) |
| `reference_fasta` | `File` | — | Reference sequence; defines the expected length and is always written first in the output |
| `collection_name` | `String` | — | Prefix for the output filename |
| `max_missing_pct` | `Float` | `20.0` | Maximum % of N bases allowed before a sample is excluded |
| `docker` | `String` | `marcoteix/cleansweep:heads-main` | |
| `memory` | `Int` | `8` | GB |
| `disk_size` | `Int` | `16` | GB |

| Output | Type | Description |
|---|---|---|
| `msa` | `File` | MSA in FASTA format, named `<collection_name>.msa.fasta` |
| `excluded_samples` | `Array[String]` | Names of samples removed due to excessive missing data |
