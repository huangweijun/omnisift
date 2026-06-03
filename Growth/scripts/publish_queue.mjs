#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const queuePath = path.join(root, "Growth", "queue", "launch-week.json");
const outboxDir = path.join(root, "Growth", "outbox");
const publishEndpoint = process.env.PROMOTION_WEBHOOK_URL || "";
const publishApiKey = process.env.PROMOTION_WEBHOOK_API_KEY || "";
const publishMode = process.env.PROMOTION_PUBLISH_MODE || "dry-run";
const launchStart = process.env.PROMOTION_LAUNCH_START || "2026-05-31";
const dayOverride = process.env.PROMOTION_DAY || "";
const channelAllowlist = new Set(
  (process.env.PROMOTION_CHANNELS || "")
    .split(",")
    .map((channel) => channel.trim())
    .filter(Boolean)
);

function daysSinceStart() {
  if (dayOverride) return Number(dayOverride);
  const start = new Date(`${launchStart}T00:00:00Z`);
  const now = new Date();
  const delta = Math.floor((now - start) / 86400000) + 1;
  return Math.max(1, Math.min(delta, 5));
}

function assertSafePost(post) {
  if (post.channel === "x" && [...post.text].length > 280) {
    throw new Error(`Blocked overlong X post in ${post.id}: ${[...post.text].length}/280`);
  }

  const blocked = [
    /unlimited/i,
    /lifetime/i,
    /终身/,
    /无限/
  ];

  for (const pattern of blocked) {
    if (pattern.test(post.text)) {
      throw new Error(`Blocked unsafe claim in ${post.id}: ${pattern}`);
    }
  }

  const lowerText = post.text.toLowerCase();
  const mentionsFullyLocal = lowerText.includes("fully local ai");
  const negatesFullyLocal = lowerText.includes("does not claim fully local ai");
  if (mentionsFullyLocal && !negatesFullyLocal) {
    throw new Error(`Blocked unsafe fully-local AI claim in ${post.id}`);
  }

  const mentionsChineseFullyLocal = post.text.includes("完全本地 AI");
  const negatesChineseFullyLocal = post.text.includes("不声称完全本地 AI");
  if (mentionsChineseFullyLocal && !negatesChineseFullyLocal) {
    throw new Error(`Blocked unsafe fully-local AI claim in ${post.id}`);
  }
}

function renderMarkdown(day, posts) {
  return [
    `# OmniSift Promotion Outbox Day ${day}`,
    "",
    `Generated: ${new Date().toISOString()}`,
    "",
    `Mode: ${publishMode}`,
    "",
    ...posts.flatMap((post) => [
      `## ${post.id}`,
      "",
      `- Channel: ${post.channel}`,
      `- Language: ${post.language}`,
      "",
      "```text",
      post.text,
      "```",
      ""
    ])
  ].join("\n");
}

async function postToWebhook(post) {
  if (!publishEndpoint) {
    throw new Error("PROMOTION_WEBHOOK_URL is required when PROMOTION_PUBLISH_MODE=webhook");
  }

  const response = await fetch(publishEndpoint, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(publishApiKey ? { "x-make-apikey": publishApiKey } : {})
    },
    body: JSON.stringify({
      product: "OmniSift",
      source: "github-actions",
      post
    })
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Webhook failed for ${post.id}: ${response.status} ${text}`);
  }
}

const queue = JSON.parse(fs.readFileSync(queuePath, "utf8"));
const day = daysSinceStart();
const posts = queue.filter((post) => post.day === day);
const publishPosts = channelAllowlist.size
  ? posts.filter((post) => channelAllowlist.has(post.channel))
  : posts;

for (const post of posts) assertSafePost(post);

fs.mkdirSync(outboxDir, { recursive: true });
const outboxPath = path.join(outboxDir, `day-${day}.md`);
fs.writeFileSync(outboxPath, renderMarkdown(day, posts));

if (publishMode === "webhook") {
  for (const post of publishPosts) {
    await postToWebhook(post);
  }
  console.log(`Published ${publishPosts.length}/${posts.length} posts for day ${day} via webhook.`);
} else {
  console.log(`Dry-run generated Growth/outbox/day-${day}.md with ${posts.length} posts.`);
}
