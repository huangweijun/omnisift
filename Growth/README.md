# OmniSift Growth System

This folder turns the growth plan into repeatable files and scripts.

## Launch Playbook

- `Growth/search-submission-checklist.md`: Google Search Console and Bing Webmaster Tools checklist.
- `Growth/auto-growth-geo-plan.md`: strategy notes for the automated promotion and GEO system.

## Current Public Positioning

OmniSift should be described as: capture ideas, light a personal knowledge star map, and use a knowledge compass to decide what to explore next. Keep pricing public as Free 5 AI processing uses per day and Pro 50 AI processing uses per day.

## Commands

Run from the repository root:

```bash
node Growth/scripts/check_geo_readiness.mjs
node Growth/scripts/generate_growth_pack.mjs
node Growth/scripts/weekly_report.mjs
node Growth/scripts/publish_queue.mjs
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
- `Growth/outbox/day-<n>.md`: promotion posts queued for a launch day

Generated files are ignored by Git by default. The GitHub Actions workflow uploads them as artifacts for review.

## Operating Rule

This system is dry-run by default. To publish automatically, connect a compliant publisher such as Buffer, Make, Zapier, or n8n through `PROMOTION_WEBHOOK_URL`, then set `PROMOTION_PUBLISH_MODE=webhook` in GitHub Actions variables. Do not use browser automation to bypass platform rate limits, bot detection, CAPTCHA, or account safety systems.
