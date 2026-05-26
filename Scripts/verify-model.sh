#!/bin/bash
# verify-model.sh
# Verifies model files are downloaded correctly and cleans up for bundling.

set -e

MODEL_DIR="Models/gemma4e2b"
MIN_CHUNK_SIZE=100000000  # 100MB minimum for a valid chunk weight

echo "=== OmniSift Model Verification ==="
echo ""

# Check key files exist and are not LFS pointers
check_file() {
    local file="$1"
    local min_size="$2"

    if [ ! -f "$file" ]; then
        echo "MISSING: $file"
        return 1
    fi

    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ "$size" -lt "$min_size" ]; then
        echo "INCOMPLETE: $file (${size} bytes, need >= ${min_size})"
        return 1
    fi

    echo "OK: $file ($(du -h "$file" | cut -f1))"
    return 0
}

ERRORS=0

check_file "$MODEL_DIR/chunk1.mlmodelc/weights/weight.bin" $MIN_CHUNK_SIZE || ((ERRORS++))
check_file "$MODEL_DIR/chunk2.mlmodelc/weights/weight.bin" $MIN_CHUNK_SIZE || ((ERRORS++))
check_file "$MODEL_DIR/chunk3.mlmodelc/weights/weight.bin" $MIN_CHUNK_SIZE || ((ERRORS++))
check_file "$MODEL_DIR/embed_tokens_q8.bin" 50000000 || ((ERRORS++))
check_file "$MODEL_DIR/embed_tokens_per_layer_q8.bin" 5000000 || ((ERRORS++))
check_file "$MODEL_DIR/embed_proj_weight.npy" 1000000 || ((ERRORS++))
check_file "$MODEL_DIR/model_config.json" 100 || ((ERRORS++))

echo ""

if [ $ERRORS -gt 0 ]; then
    echo "FAILED: $ERRORS file(s) missing or incomplete."
    echo "Downloads may still be in progress. Check with:"
    echo "  ls -lh $MODEL_DIR/chunk1.mlmodelc/weights/weight.bin"
    exit 1
fi

echo "All model files verified!"
echo ""

# Clean up .git directory (saves ~1GB in app bundle)
if [ -d "$MODEL_DIR/.git" ]; then
    echo "Removing .git directory to reduce bundle size..."
    rm -rf "$MODEL_DIR/.git"
    echo "Removed .git (saved ~$(du -sh "$MODEL_DIR/.git" 2>/dev/null | cut -f1 || echo '1GB'))"
fi

# Remove unnecessary variant directories (we only need the base 3-chunk model)
for dir in lite lite-chunks mf prefill sdpa sdpa-8k stateless stateless-ctx2048 swa w8a8-8k; do
    if [ -d "$MODEL_DIR/$dir" ]; then
        echo "Removing unused variant: $dir"
        rm -rf "$MODEL_DIR/$dir"
    fi
done

# Remove non-essential files
rm -f "$MODEL_DIR/README.md"
rm -rf "$MODEL_DIR/model.mlpackage"
rm -rf "$MODEL_DIR/vision.mlpackage"
rm -rf "$MODEL_DIR/audio.mlmodelc"
rm -rf "$MODEL_DIR/vision.mlmodelc"
rm -rf "$MODEL_DIR/vision_video.mlmodelc"
rm -rf "$MODEL_DIR/model.mlmodelc"
rm -rf "$MODEL_DIR/hf_model"
rm -f "$MODEL_DIR/mel_filterbank.bin"
rm -f "$MODEL_DIR/audio_config.json"

echo ""
echo "=== Cleanup Complete ==="
echo "Final model size: $(du -sh "$MODEL_DIR" | cut -f1)"
echo ""
echo "Ready for Xcode build! Run:"
echo "  cd $(pwd)"
echo "  xcodegen generate"
echo "  open OmniSift.xcodeproj"
