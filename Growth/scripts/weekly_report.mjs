#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();

function isoWeek(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

const week = process.argv[2] || isoWeek(new Date());
const metricsDir = path.join(root, "Growth", "metrics");
fs.mkdirSync(metricsDir, { recursive: true });
const filePath = path.join(metricsDir, `${week}.md`);

if (fs.existsSync(filePath)) {
  console.log(`Metrics file already exists: Growth/metrics/${week}.md`);
  process.exit(0);
}

const body = `
# OmniSift Weekly Metrics ${week}

## Search

- Google Search Console impressions:
- Google Search Console clicks:
- Google indexed pages:
- Bing impressions:
- Bing clicks:
- Bing indexed pages:

## GEO

- ChatGPT / OpenAI search referrals noticed:
- Perplexity referrals noticed:
- Claude referrals noticed:
- Other AI answer mentions:
- Query tested:
- Answer quality notes:

## Website

- Top page:
- FAQ visits:
- Use cases visits:
- Compare visits:
- Email launch notice clicks:

## App Store

- App Store status:
- Product page views:
- Downloads:
- First card activations:
- Pro paywall views:
- Purchases:

## Content

- Posts drafted:
- Posts published:
- Best performing topic:
- Topic to repeat:
- Topic to stop:

## Decisions

- Title/meta to update:
- FAQ to add or improve:
- Next content angle:
`;

fs.writeFileSync(filePath, body.trim() + "\n");
console.log(`Created Growth/metrics/${week}.md`);
