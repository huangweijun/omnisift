# OmniSift Growth System

This folder turns the growth plan into repeatable files and scripts.

## Commands

Run from the repository root:

```bash
node Growth/scripts/check_geo_readiness.mjs
node Growth/scripts/generate_growth_pack.mjs
node Growth/scripts/weekly_report.mjs
```

Optional week override:

```bash
node Growth/scripts/generate_growth_pack.mjs 2026-W22
node Growth/scripts/weekly_report.mjs 2026-W22
```

## What Gets Generated

- `Growth/dist/<week>/`: weekly blog, social, video, and keyword drafts
- `Growth/dist/geo-readiness-report.md`: technical GEO/SEO check output
- `Growth/metrics/<week>.md`: manual weekly metrics template

Generated files are ignored by Git by default. The GitHub Actions workflow uploads them as artifacts for review.

## Operating Rule

This system generates drafts. It does not auto-publish. Review product claims, App Store status, screenshots, and privacy wording before posting anything publicly.
