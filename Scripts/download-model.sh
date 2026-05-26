#!/bin/bash
# download-model.sh
# Downloads the Gemma 4 E2B CoreML model from HuggingFace for bundling in the app.
# Run this once during development to populate the Models/ directory.
#
# Requires: huggingface-cli (pip install huggingface_hub)
# Total size: ~1.5 GB

set -e

MODEL_DIR="Models/gemma4e2b"
REPO="mlboydaisuke/gemma-4-E2B-coreml"
BRANCH="n1024"  # 3-chunk merged decoder, faster prefill

echo "=== OmniSift Model Download ==="
echo "Repo: $REPO (branch: $BRANCH)"
echo "Target: $MODEL_DIR"
echo ""

# Check for huggingface-cli
if ! command -v huggingface-cli &> /dev/null; then
    echo "ERROR: huggingface-cli not found."
    echo "Install: pip install huggingface_hub"
    echo "  or: brew install huggingface-cli"
    exit 1
fi

# Create target directory
mkdir -p "$MODEL_DIR"

# Download model files (exclude conversion scripts and docs)
echo "Downloading model files..."
hf download "$REPO" \
    --revision "$BRANCH" \
    --local-dir "$MODEL_DIR" \
    --include "*.mlmodelc/*" "*.bin" "*.npy" "model_config.json" "hf_model/*" \
    --exclude "conversion/*" "docs/*" "Examples/*" "*.py" "*.md"

echo ""
echo "=== Download Complete ==="
echo "Model size: $(du -sh "$MODEL_DIR" | cut -f1)"
echo ""
echo "The model is now at: $MODEL_DIR"
echo "It will be bundled into the app at build time."
echo ""
echo "NOTE: Do NOT commit this to git (it's in .gitignore)."
