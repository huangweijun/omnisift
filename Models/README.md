# Models Directory

This directory contains the Gemma 4 E2B CoreML model (~1.5 GB).

**The model files are NOT tracked in git** (too large).

## Setup

Run the download script once after cloning:

```bash
./Scripts/download-model.sh
```

This downloads the pre-converted INT4 model from HuggingFace:
- Repo: `mlboydaisuke/gemma-4-E2B-coreml` (branch: `n1024`)
- Size: ~1.5 GB
- Format: CoreML `.mlmodelc` + INT8 embeddings + tokenizer

## What gets bundled

The entire `Models/gemma4e2b/` directory is included in the app bundle
as a folder reference. At runtime, `CoreMLLLM.load(from:)` reads from
`Bundle.main/Models/gemma4e2b/`.

## Requirements

- `huggingface-cli` (`pip install huggingface_hub`)
- ~2 GB free disk space
