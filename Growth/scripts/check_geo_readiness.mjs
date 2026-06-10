#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const docsDir = path.join(root, "docs");
const requiredPages = [
  { file: "index.html", url: "https://omnisift.app/", jsonLd: true },
  { file: "use-cases.html", url: "https://omnisift.app/use-cases.html" },
  { file: "first-card.html", url: "https://omnisift.app/first-card.html", jsonLd: true },
  { file: "capture-first-note-taking.html", url: "https://omnisift.app/capture-first-note-taking.html", jsonLd: true },
  { file: "compare.html", url: "https://omnisift.app/compare.html" },
  { file: "faq.html", url: "https://omnisift.app/faq.html", jsonLd: true },
  { file: "changelog.html", url: "https://omnisift.app/changelog.html", jsonLd: true },
  { file: "save-ai-answers.html", url: "https://omnisift.app/save-ai-answers.html", jsonLd: true },
  { file: "privacy-policy.html", url: "https://omnisift.app/privacy-policy.html" }
];

const errors = [];
const warnings = [];

function read(file) {
  return fs.readFileSync(path.join(docsDir, file), "utf8");
}

function count(re, text) {
  return [...text.matchAll(re)].length;
}

function requireIncludes(label, text, needle) {
  if (!text.includes(needle)) errors.push(`${label}: missing ${needle}`);
}

for (const page of requiredPages) {
  const html = read(page.file);
  const label = `docs/${page.file}`;

  if (count(/<h1[\s>]/g, html) !== 1) errors.push(`${label}: expected exactly one H1`);
  if (count(/<title>/g, html) !== 1) errors.push(`${label}: expected exactly one title`);
  if (count(/name="description"/g, html) !== 1) errors.push(`${label}: expected exactly one meta description`);
  if (count(/rel="canonical"/g, html) !== 1) errors.push(`${label}: expected exactly one canonical`);
  requireIncludes(label, html, `href="${page.url}"`);
  requireIncludes(label, html, `content="${page.url}"`);

  const jsonBlocks = [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
  if (page.jsonLd && jsonBlocks.length === 0) errors.push(`${label}: missing JSON-LD`);
  for (const [index, block] of jsonBlocks.entries()) {
    try {
      JSON.parse(block[1].trim());
    } catch (error) {
      errors.push(`${label}: JSON-LD block ${index + 1} is invalid: ${error.message}`);
    }
  }

  if (/fully local AI|完全本地 AI/.test(html)) {
    warnings.push(`${label}: contains fully-local AI wording; confirm it is negated and accurate`);
  }
}

const sitemap = read("sitemap.xml");
for (const page of requiredPages) {
  requireIncludes("docs/sitemap.xml", sitemap, `<loc>${page.url}</loc>`);
}
requireIncludes("docs/robots.txt", read("robots.txt"), "Sitemap: https://omnisift.app/sitemap.xml");

const llms = read("llms.txt");
for (const phrase of [
  "iOS AI knowledge capture app",
  "iOS Share Sheet",
  "stored locally on device",
  "cloud AI for processing only",
  "Free: 5 AI processing uses per day",
  "OmniSift Pro: designed for 50 AI processing uses per day",
  "App Store: https://apps.apple.com/us/app/omnisift/id6773056945?uo=4",
  "Current release: v1.0.0 is live on the App Store"
]) {
  requireIncludes("docs/llms.txt", llms, phrase);
}

const siteJs = read("site.js");
if (!siteJs.includes('appStoreUrl: ""')) {
  warnings.push("docs/site.js: App Store URL is set; verify CTA and llms.txt App Store status");
}

const report = [
  "# GEO Readiness Report",
  "",
  `Generated: ${new Date().toISOString()}`,
  "",
  `Errors: ${errors.length}`,
  `Warnings: ${warnings.length}`,
  "",
  "## Errors",
  "",
  errors.length ? errors.map((e) => `- ${e}`).join("\n") : "- None",
  "",
  "## Warnings",
  "",
  warnings.length ? warnings.map((w) => `- ${w}`).join("\n") : "- None",
  "",
  "## Checked",
  "",
  requiredPages.map((page) => `- ${page.url}`).join("\n"),
  "- https://omnisift.app/robots.txt",
  "- https://omnisift.app/sitemap.xml",
  "- https://omnisift.app/llms.txt",
  ""
].join("\n");

const outDir = path.join(root, "Growth", "dist");
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "geo-readiness-report.md"), report);

console.log(report);
if (errors.length > 0) process.exit(1);
