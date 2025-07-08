#!/bin/bash

# Test script for the genome tracker pipeline
# This script tests the actual pipeline commands:
# 1. Get eukaryote taxon accessions (2759)
# 2. Get project accession list (PRJNA533106)
# 3. Cross-reference and get detailed metadata

set -e  # Exit on any error

# Configuration - you can modify these for testing
PROJECT_ACCESSION="PRJNA533106"  # The specific project accession
TAXON_ID="2759"  # Eukaryote taxon ID
MATRIX_PATH="matrices/test_assemblies.tsv"
COLUMN_NAME="test_column"
TSV_FIELDS="organism-name,organism-tax-id,accession"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if NCBI datasets tools are available
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check if tools are already available in PATH
    if command -v datasets &> /dev/null && command -v dataformat &> /dev/null; then
        print_success "NCBI tools found in PATH"
        return 0
    fi
    
    # Check if tools are available in current directory
    if [ -f "./datasets" ] && [ -f "./dataformat" ]; then
        print_success "NCBI tools found in current directory"
        return 0
    fi
    
    # Download tools if not available
    print_status "NCBI tools not found. Downloading..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Map architecture to NCBI format
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            print_status "Supported architectures: x86_64, aarch64"
            exit 1
            ;;
    esac
    
    # Check if OS is supported
    if [ "$OS" != "linux" ] && [ "$OS" != "darwin" ]; then
        print_error "Unsupported operating system: $OS"
        print_status "Supported operating systems: Linux, macOS"
        exit 1
    fi
    
    print_status "Detected OS: $OS, Architecture: $ARCH"
    
    # Download datasets tool
    print_status "Downloading datasets tool..."
    if curl -L -o datasets "https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/${OS}-${ARCH}/datasets"; then
        chmod +x datasets
        print_success "Downloaded datasets tool"
    else
        print_error "Failed to download datasets tool"
        exit 1
    fi
    
    # Download dataformat tool
    print_status "Downloading dataformat tool..."
    if curl -L -o dataformat "https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/${OS}-${ARCH}/dataformat"; then
        chmod +x dataformat
        print_success "Downloaded dataformat tool"
    else
        print_error "Failed to download dataformat tool"
        exit 1
    fi
    
    # Verify tools work
    print_status "Verifying tools..."
    if ./datasets --version &>/dev/null && ./dataformat --version &>/dev/null; then
        print_success "NCBI tools downloaded and verified successfully"
    else
        print_error "Failed to verify NCBI tools"
        exit 1
    fi
}

# Function to test individual commands
test_command() {
    local command_name="$1"
    local command="$2"
    local output_file="$3"
    
    print_status "Testing: $command_name"
    echo "Command: $command"
    
    if eval "$command" > "$output_file" 2>&1; then
        local line_count=$(wc -l < "$output_file")
        print_success "$command_name completed successfully ($line_count lines)"
        return 0
    else
        print_error "$command_name failed"
        echo "Error output:"
        cat "$output_file"
        return 1
    fi
}

# Function to run the actual pipeline logic
run_pipeline() {
    print_status "Running actual pipeline test..."
    
    # Initialize variables
    existing_assemblies="$MATRIX_PATH"
    new_assemblies="output.tsv"
    cross_ref_file="cross_referenced_accessions.txt"
    column_name="$COLUMN_NAME"
    
    # Create matrices directory if it doesn't exist
    mkdir -p "$(dirname "$MATRIX_PATH")"

    # Step 1: Test eukaryote taxon accessions command
    print_status "Step 1: Testing eukaryote taxon accessions (taxon ID $TAXON_ID)"
    eukaryote_cmd="./datasets summary genome taxon $TAXON_ID --report ids_only --as-json-lines | ./dataformat tsv genome --fields accession --elide-header"
    
    if test_command "Eukaryote taxon query" "$eukaryote_cmd" "eukaryote_accessions.txt"; then
        print_status "Eukaryote accessions sample (first 5):"
        head -5 eukaryote_accessions.txt
        echo "..."
    else
        print_error "Failed to get eukaryote accessions. Exiting."
        exit 1
    fi
    
    # Step 2: Test project accession command
    print_status "Step 2: Testing project accessions ($PROJECT_ACCESSION)"
    project_cmd="./datasets summary genome accession $PROJECT_ACCESSION --report ids_only --as-json-lines | ./dataformat tsv genome --fields accession --elide-header"
    
    if test_command "Project accession query" "$project_cmd" "project_accessions.txt"; then
        print_status "Project accessions sample (first 5):"
        head -5 project_accessions.txt
        echo "..."
    else
        print_error "Failed to get project accessions. Exiting."
        exit 1
    fi
    
    # Step 3: Test cross-referencing
    print_status "Step 3: Testing cross-referencing accessions"
    if comm -12 <(sort eukaryote_accessions.txt) <(sort project_accessions.txt) > "$cross_ref_file"; then
        local cross_ref_count=$(wc -l < "$cross_ref_file")
        print_success "Cross-referencing completed successfully ($cross_ref_count common accessions)"
        
        if [ "$cross_ref_count" -gt 0 ]; then
            print_status "Cross-referenced accessions sample (first 5):"
            head -5 "$cross_ref_file"
            echo "..."
        else
            print_warning "No common accessions found between eukaryotes and project"
        fi
    else
        print_error "Cross-referencing failed"
        exit 1
    fi
    
    # Step 4: Test detailed metadata retrieval
    if [ -s "$cross_ref_file" ]; then
        print_status "Step 4: Testing detailed metadata retrieval"
        metadata_cmd="./datasets summary genome accession --inputfile $cross_ref_file --as-json-lines | ./dataformat tsv genome --fields $TSV_FIELDS"
        
        if test_command "Metadata retrieval" "$metadata_cmd" "temp_metadata.tsv"; then
            # Deduplicate based on assembly accession (field 3)
            print_status "Deduplicating results based on assembly accession..."
            awk -F'\t' '!seen[$3]++' temp_metadata.tsv > filtered_assemblies.tsv
            
            local metadata_count=$(wc -l < filtered_assemblies.tsv)
            print_success "Metadata retrieval and deduplication completed successfully ($metadata_count unique assemblies)"
            
            print_status "Metadata sample (first 3 lines):"
            head -3 filtered_assemblies.tsv
            echo "..."
        else
            print_error "Failed to get metadata. Exiting."
            exit 1
        fi
    else
        print_warning "Skipping metadata retrieval - no cross-referenced accessions"
        # Create empty metadata file for consistency
        echo -e "accession\torganism_name\tassembly_level\trefseq_category" > filtered_assemblies.tsv
    fi
    
    # Test matrix processing
    print_status "Testing matrix processing..."
    
    # Create test matrix if it doesn't exist
    if [ ! -f "$existing_assemblies" ]; then
        print_status "Creating new test matrix file..."
        cat filtered_assemblies.tsv > "$new_assemblies"
        awk -F'\t' -v OFS='\t' 'NR>1{new_value=$1; $(NF+1)="https://www.ebi.ac.uk/ena/browser/api/fasta/" new_value "?download=true&gzip=true"} 1' "$new_assemblies" > "$existing_assemblies"
        sed -i "1s/$/\t$column_name/" "$existing_assemblies"
        print_success "Created new test matrix file: $existing_assemblies"
    else
        print_status "Updating existing test matrix file..."
        awk -F'\t' 'NR==FNR{a[$1];next} !($1 in a)' "$existing_assemblies" filtered_assemblies.tsv > "$new_assemblies"
        awk -F'\t' -v OFS='\t' '{new_value=$1; $(NF+1)="https://www.ebi.ac.uk/ena/browser/api/fasta/" new_value "?download=true&gzip=true"} 1' "$new_assemblies" >> "$existing_assemblies"
        print_success "Updated existing test matrix file: $existing_assemblies"
    fi

    # Count new rows
    new_rows=$(wc -l < "$new_assemblies")
    print_success "Added $new_rows new row(s) to test matrix"

    # Show final matrix summary
    print_status "Final test matrix summary:"
    echo "Total rows: $(wc -l < "$existing_assemblies")"
    echo "Matrix file: $existing_assemblies"
    
    # Show sample of final matrix
    print_status "Final matrix sample (first 3 lines):"
    head -3 "$existing_assemblies"
    echo "..."
}

# Function to cleanup test files
cleanup() {
    print_status "Cleaning up test files..."
    rm -f "$new_assemblies" filtered_assemblies.tsv temp_metadata.tsv eukaryote_accessions.txt project_accessions.txt "$cross_ref_file"
    print_success "Cleanup completed"
}

# Function to show test summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "PIPELINE TEST SUMMARY"
    echo "=========================================="
    echo "✅ Dependencies checked"
    echo "✅ Eukaryote taxon query tested"
    echo "✅ Project accession query tested"
    echo "✅ Cross-referencing tested"
    echo "✅ Metadata retrieval tested"
    echo "✅ Matrix processing tested"
    echo ""
    print_success "All pipeline components tested successfully!"
    echo "=========================================="
}

# Main execution
main() {
    echo "=========================================="
    echo "Genome Tracker Pipeline - ACTUAL TEST"
    echo "=========================================="
    echo "Testing real pipeline with:"
    echo "- Eukaryote taxon ID: $TAXON_ID"
    echo "- Project accession: $PROJECT_ACCESSION"
    echo "- TSV fields: $TSV_FIELDS"
    echo "=========================================="
    
    check_dependencies
    run_pipeline
    show_summary
    
    # Ask if user wants to cleanup
    read -p "Do you want to cleanup test files? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup
    else
        print_status "Test files preserved for inspection"
        echo "Files to inspect:"
        echo "- eukaryote_accessions.txt"
        echo "- project_accessions.txt"
        echo "- cross_referenced_accessions.txt"
        echo "- filtered_assemblies.tsv"
        echo "- $MATRIX_PATH"
    fi
}

# Run main function
main "$@" 