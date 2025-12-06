#!/bin/bash

# Exit on error
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
PYTHON_ENV_DIR="$PROJECT_ROOT/Resources/python_env"
PYTHON_SOURCE_DIR="$PROJECT_ROOT/Python"

# Create Python virtual environment
python3 -m venv "$PYTHON_ENV_DIR"

# Activate virtual environment
source "$PYTHON_ENV_DIR/bin/activate"

# Install requirements
pip install -r "$PYTHON_SOURCE_DIR/requirements.txt"

# Copy Python scripts to the virtual environment
cp "$PYTHON_SOURCE_DIR"/*.py "$PYTHON_ENV_DIR/"

# Deactivate virtual environment
deactivate

echo "Python environment setup complete"
