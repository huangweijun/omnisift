#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const growthDir = path.join(root, "Growth");
const sourcesDir = path.join(growthDir, "sources");
const distDir = path.join(growthDir, "dist");

function read(name) {
  return fs.readFileSync(path.join(sourcesDir, name), "utf8");
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function isoWeek(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

function writeFile(dir, name, body) {
  fs.writeFileSync(path.join(dir, name), `${body.trim()}\n`);
}

const week = process.argv[2] || isoWeek(new Date());
const outDir = path.join(distDir, week);
ensureDir(outDir);

const productFacts = read("product-facts.md");
const useCases = read("use-cases.md");
const competitors = read("competitors.md");
const faq = read("faq.md");
const releaseNotes = read("release-notes.md");
const distribution = read("distribution.md");

const appStoreUrl = "https://apps.apple.com/us/app/omnisift/id6773056945?uo=4";
const launchCta = `Download on the App Store: ${appStoreUrl}`;
const primaryUrl = "https://omnisift.app/";

const angle = {
  en: "Most useful ideas do not begin inside a notes app.",
  zh: "很多有价值的想法，并不是从笔记软件里开始的。"
};

writeFile(outDir, "brief.md", `
# OmniSift Weekly Growth Pack ${week}

## Core angle

${angle.en}

${angle.zh}

## Source files

- Growth/sources/product-facts.md
- Growth/sources/use-cases.md
- Growth/sources/competitors.md
- Growth/sources/faq.md
- Growth/sources/release-notes.md
- Growth/sources/distribution.md

## Publish rule

Drafts are ready for human review only. Do not auto-post before checking product claims, App Store status, and screenshots.

## Current CTA

${launchCta}
`);

writeFile(outDir, "blog.en.md", `
# Capture AI answers before they disappear

A useful answer from ChatGPT or Claude often has a short half-life. You read it, use part of it, switch apps, and later remember that the answer existed but not where it was.

The old workaround is copy-paste. Select the paragraph, open a notes app, create a page, paste it, maybe add a title, maybe add tags, then hope future-you can find it.

OmniSift is built for the smaller moment before all of that. Share the useful section from iOS, and OmniSift turns it into a structured knowledge card with a title, summary, highlights, tags, named entities, and relations.

The privacy boundary is simple: no account is required, cards are stored locally on device, and text you explicitly share is sent to cloud AI for processing only. OmniSift does not claim fully local AI.

Use it when a fragment matters but writing a full note would be too much ceremony.

${launchCta}

Source: ${primaryUrl}
`);

writeFile(outDir, "blog.zh.md", `
# 先把 AI 回答里真正有用的部分留下来

ChatGPT 或 Claude 的长回答里，经常只有一两段是你真的想复用的。问题是，读完以后你很快会切到别的 App，再过几天只记得「好像有个回答不错」，但忘了在哪里。

老办法是复制粘贴：选中一段文字，打开笔记软件，新建页面，粘贴，起标题，加标签。很多时候，真正丢失的不是内容，而是整理这一步的动力。

知漏适合处理这个更小的动作：在 iOS 里把有用片段分享给知漏，AI 自动整理成标题、摘要、高亮、标签、实体和关系，生成一张结构化知识卡片。

隐私边界也要说清楚：无需账号，卡片保存在设备本地；你主动分享的文本会发送到云端 AI 做处理。知漏不声称 AI 完全本地运行。

当一个片段值得留下，但还不值得写成一整页笔记时，这就是知漏的使用时刻。

${launchCta}

官网：${primaryUrl}
`);

writeFile(outDir, "x-thread.en.md", `
Most useful ideas do not begin inside your notes app.

They show up in:
- a Claude answer
- a Safari paragraph
- a chat message
- a screenshot
- a half-read thread

The problem is not saving everything. The problem is saving the one fragment that will matter later.

OmniSift is an iOS Share Sheet workflow for that moment.

Share text, links, articles, or screenshots from another app. Cloud AI extracts a title, summary, highlights, tags, named entities, and relations.

The resulting card is stored locally on device. No account is required. No analytics or behavioral tracking.

It is not a replacement for writing long notes.

It is for the capture step before writing, organizing, or forgetting.

${launchCta}
`);

writeFile(outDir, "x-thread.zh.md", `
很多知识不是丢在笔记软件里。

而是丢在「还没来得及整理」这一步。

它们可能来自：
- Claude 的一段回答
- Safari 的一个段落
- 微信里的一句话
- 一张截图
- 一条看到一半的帖子

知漏做的事很窄：

从 iOS 任意 App 分享文本、链接、文章或截图，然后用 AI 整理成标题、摘要、高亮、标签、实体和关系。

生成的卡片保存在设备本地。

无需账号。
无分析追踪。

但也要说清楚：你主动分享的文本会发送到云端 AI 做处理，知漏不声称完全本地 AI。

它不是替代长笔记。

它是帮你先把值得留下的片段抓住。

${launchCta}
`);

writeFile(outDir, "linkedin.en.md", `
Most note-taking tools start from a blank page.

That is useful when you already know what you want to write. It is less useful when the idea appears somewhere else first: inside an AI answer, a browser paragraph, a chat message, or a screenshot.

OmniSift is built around that earlier moment.

On iOS, you share text, links, articles, or screenshots from another app. OmniSift uses cloud AI to turn the snippet into a structured knowledge card: title, summary, highlights, tags, named entities, and relations.

The product boundary matters:

- no account required
- no analytics or behavioral tracking
- cards stored locally on device
- shared text sent to cloud AI for processing only

It is not trying to replace every notes app. It focuses on cross-app capture before useful fragments disappear.

${launchCta}
`);

writeFile(outDir, "linkedin.zh.md", `
大多数笔记工具从一张空白页开始。

这适合写完整内容，但不适合捕获那些已经出现在别处的片段：AI 回答、网页段落、聊天消息、截图、临时灵感。

知漏关注的是更早一步。

在 iOS 上，用户从任意 App 分享文本、链接、文章或截图。知漏用云端 AI 把片段整理成结构化知识卡片：标题、摘要、高亮、标签、实体和关系。

产品边界很明确：

- 无需账号
- 无分析追踪
- 卡片保存在设备本地
- 主动分享的文本仅在处理时发送到云端 AI

它不是要替代所有笔记软件，而是专注解决「跨 App 捕获」这个很小但高频的问题。

${launchCta}
`);

writeFile(outDir, "short-video-script.zh.md", `
# 30 秒短视频脚本：AI 回答怎么保存

## 0-3 秒

画面：ChatGPT 或 Claude 长回答，手指划过其中一段。

旁白：有些 AI 回答很有用，但你很快就找不到了。

## 4-10 秒

画面：选中一段内容，打开 iOS 分享菜单，选择知漏。

旁白：不用新建笔记，直接从分享菜单发送到知漏。

## 11-22 秒

画面：知识卡片生成，出现标题、摘要、高亮、标签。

旁白：AI 会整理成标题、摘要、高亮、标签和关联实体。

## 23-30 秒

画面：卡片列表和知识图谱/相关洞察。

旁白：卡片保存在本地。等你需要回顾时，它已经整理好了。

字幕：知漏 OmniSift - iOS 跨应用 AI 知识碎片收集
CTA：在 App Store 下载：${appStoreUrl}
`);

writeFile(outDir, "appstore-keyword-notes.md", `
# App Store Keyword Notes ${week}

## English candidates

- AI notes
- snippet capture
- share extension
- knowledge cards
- AI summary
- knowledge graph
- highlight organizer
- research notes

## Chinese candidates

- AI 笔记
- 知识管理
- 碎片整理
- 知识卡片
- 分享扩展
- AI 摘要
- 知识图谱
- 网页收藏

## Current public metadata boundary

- Free: 5 AI processing uses per day.
- Pro: 50 AI processing uses per day.
- Price: ¥12/month or ¥68/year.
- Do not mention lifetime or unlimited.
`);

writeFile(outDir, "source-snapshot.md", `
# Source Snapshot ${week}

## product-facts.md

${productFacts}

## use-cases.md

${useCases}

## competitors.md

${competitors}

## faq.md

${faq}

## release-notes.md

${releaseNotes}

## distribution.md

${distribution}
`);

console.log(`Generated Growth/dist/${week}`);
