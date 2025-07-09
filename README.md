# EBP Assemblies Tracker

A GitHub Actions workflow that automatically tracks genome assemblies by cross-referencing eukaryote taxon data with the Earth BioGenome Project (EBP).

## Observable Notebook

See the TSV file as a data table [here](https://observablehq.com/d/0d1aaf560f6380d7)

## 🎯 Purpose

This repository contains an automated pipeline that:
- Monitors genome assemblies from the Earth BioGenome Project (EBP)
- Cross-references eukaryote assemblies with specific project accessions
- Creates a tracking matrix with new assemblies

## 🔄 GitHub Actions Workflow

### Overview
The workflow runs automatically every day at midnight UTC and performs the following steps:

1. **Retrieve Eukaryote Assemblies**: Gets all genome assemblies under eukaryote taxon ID 2759
2. **Retrieve Project Assemblies**: Gets assemblies from specific EBP project accession PRJNA533106
3. **Cross-reference**: Finds common assemblies between eukaryotes and the project
4. **Get Metadata**: Retrieves detailed metadata for the cross-referenced assemblies
5. **Create Matrix**: Creates the matrix

### Workflow File: `.github/workflows/main.yml`

#### Schedule
```yaml
schedule:
  - cron: '0 0 * * *'  # Runs every day at midnight UTC
```
## 🔧 Configuration

### Environment Variables
The workflow uses environment variables loaded from a `.env` file:

- `MATRIX_PATH`: Path to the output matrix file
- `TSV_FIELDS`: Fields to extract from NCBI datasets
- `PROJECT_ACCESSION`: NCBI project accession to track
- `DATASET_EXTRA_ARGS`: Additional arguments for NCBI datasets queries

### Example `.env` file:
```env
PROJECT_ACCESSION=PRJNA533106
ROOT_TAXON=2759
TSV_FIELDS=organism-name,organism-tax-id,accession,assminfo-name,assminfo-release-date,assminfo-biosample-accession,assminfo-bioproject,assminfo-bioproject-lineage-parent-accessions,source_database
MATRIX_PATH=./data/ebp-eukaryotes.tsv

```

## 🧪 Testing

### Local Testing
Use the included test script to validate the pipeline locally:

```bash
chmod +x test_pipeline.sh
./test_pipeline.sh
```
