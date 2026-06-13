#!/bin/bash

# Function to print usage
usage() {
  echo "Usage: $0 -p PROJECT_NAME -w WORKSPACE1,WORKSPACE2,... -m MODULE1,MODULE2,..."
  exit 1
}

# Parse command-line arguments
while getopts "p:w:m:" opt; do
  case $opt in
    p)
      PROJECT_NAME="$OPTARG"
      ;;
    w)
      IFS=',' read -r -a WORKSPACES <<< "$OPTARG"
      ;;
    m)
      IFS=',' read -r -a MODULES <<< "$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done

# Check if required arguments are provided
if [ -z "$PROJECT_NAME" ] || [ -z "${WORKSPACES}" ] || [ -z "${MODULES}" ]; then
  usage
fi

# Define the project root directory
PROJECT_ROOT="$PROJECT_NAME"

# Create the directory structure
mkdir -p "$PROJECT_ROOT"
for workspace in "${WORKSPACES[@]}"; do
  mkdir -p "$PROJECT_ROOT/$workspace"
  for module in "${MODULES[@]}"; do
    mkdir -p "$PROJECT_ROOT/$workspace/$module"
    # Create main.tf, variables.tf, and outputs.tf in each module
    touch "$PROJECT_ROOT/$workspace/$module/main.tf"
    touch "$PROJECT_ROOT/$workspace/$module/variables.tf"
    touch "$PROJECT_ROOT/$workspace/$module/outputs.tf"
  done
  # Create a .tfvars file for each workspace
  touch "$PROJECT_ROOT/$workspace/terraform.tfvars"
done

# Optionally create a root module for the overall project
mkdir -p "$PROJECT_ROOT/root"
touch "$PROJECT_ROOT/root/main.tf"
touch "$PROJECT_ROOT/root/variables.tf"
touch "$PROJECT_ROOT/root/outputs.tf"

# Create a .gitignore file if you use git, to ignore sensitive files and directories
echo "*.tfstate" > "$PROJECT_ROOT/.gitignore"
echo "*.tfstate.*" >> "$PROJECT_ROOT/.gitignore"
echo ".terraform/" >> "$PROJECT_ROOT/.gitignore"

echo "Terraform modules and workspaces structure for project '$PROJECT_NAME' created successfully!"
