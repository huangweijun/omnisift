#!/bin/bash
# robust-download.sh
# Downloads model files with automatic resume and retry.
# Run this script repeatedly until all files are complete.

set -e

MODEL_DIR="/Users/huangweijun/app_project/OmniSift/Models/gemma4e2b"
BASE_URL="https://huggingface.co/mlboydaisuke/gemma-4-E2B-coreml/resolve/n1024"

# Files to download with their expected minimum sizes (bytes)
declare -A FILES=(
    ["chunk1.mlmodelc/weights/weight.bin"]=400000000
    ["chunk2.mlmodelc/weights/weight.bin"]=400000000
    ["chunk3.mlmodelc/weights/weight.bin"]=400000000
    ["embed_tokens_q8.bin"]=200000000
    ["embed_tokens_per_layer_q8.bin"]=100000000
    ["embed_proj_weight.npy"]=1000000
)

echo "=== OmniSift Robust Model Download ==="
echo "Using resume + retry for unreliable connections"
echo ""

COMPLETED=0
TOTAL=${#FILES[@]}

for file in "${!FILES[@]}"; do
    min_size=${FILES[$file]}
    full_path="$MODEL_DIR/$file"

    # Check if already complete
    if [ -f "$full_path" ]; then
        size=$(stat -f%z "$full_path" 2>/dev/null || stat -c%s "$full_path" 2>/dev/null)
        if [ "$size" -ge "$min_size" ]; then
            echo "DONE: $file ($(numfmt --to=iec $size 2>/dev/null || echo "${size}B"))"
            ((COMPLETED++))
            continue
        fi
    fi

    echo "Downloading: $file..."
    curl -L -C - \
        --connect-timeout 30 \
        --retry 10 \
        --retry-delay 5 \
        --retry-max-time 3600 \
        --progress-bar \
        -o "$full_path" \
        "$BASE_URL/$file" || true

    # Verify after download
    if [ -f "$full_path" ]; then
        size=$(stat -f%z "$full_path" 2>/dev/null || stat -c%s "$full_path" 2>/dev/null)
        if [ "$size" -ge "$min_size" ]; then
            echo "COMPLETE: $file"
            ((COMPLETED++))
        else
            echo "INCOMPLETE: $file ($size bytes, need $min_size+). Run script again."
        fi
    fi
    echo ""
done

echo ""
echo "=== Status: $COMPLETED / $TOTAL files complete ==="

if [ $COMPLETED -eq $TOTAL ]; then
    echo "All files downloaded! Running verify script..."
    bash "$(dirname "$0")/verify-model.sh"
else
    echo "Some files still incomplete. Run this script again to resume."
fi
