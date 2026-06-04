#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const queuePath = path.join(root, "Growth", "queue", "launch-week.json");
const policyPath = path.join(root, "Growth", "promotion-policy.json");
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
const policy = fs.existsSync(policyPath)
  ? JSON.parse(fs.readFileSync(policyPath, "utf8"))
  : {};
const approvalPolicy = policy.approvalPolicy || {};
const redditPolicy = approvalPolicy.reddit || {};
const approvedChannels = new Set(approvalPolicy.autoPublishChannels || []);
const blockedClaimPatterns = [
  /unlimited/i,
  /lifetime/i,
  /终身/,
  /无限/
];

function daysSinceStart() {
  if (dayOverride) return Number(dayOverride);
  const start = new Date(`${launchStart}T00:00:00Z`);
  const now = new Date();
  const delta = Math.floor((now - start) / 86400000) + 1;
  return Math.max(1, delta);
}

function listReviewFindings(post) {
  const findings = [];
  const text = post.text || "";

  if (approvedChannels.size && !approvedChannels.has(post.channel)) {
    findings.push(`channel ${post.channel} is not enabled for auto-publishing`);
  }

  if (post.channel === "x" && [...text].length > 280) {
    findings.push(`X post is too long: ${[...text].length}/280`);
  }

  if (post.channel === "reddit") {
    const mode = post.redditMode || "draft";
    const title = post.title || "";
    const subreddit = post.subreddit || "";

    if (!title) findings.push("Reddit post is missing a title");
    if ([...title].length > 300) {
      findings.push(`Reddit title is too long: ${[...title].length}/300`);
    }

    if (mode === "profile") {
      const expectedProfileSubreddit = redditPolicy.profileSubreddit || "";
      if (!subreddit || !/^u_[A-Za-z0-9_-]+$/.test(subreddit)) {
        findings.push("Reddit profile post must target a u_username profile subreddit");
      }
      if (expectedProfileSubreddit && subreddit !== expectedProfileSubreddit) {
        findings.push(`Reddit profile target ${subreddit} does not match policy target ${expectedProfileSubreddit}`);
      }
    } else if (mode === "community") {
      if (redditPolicy.allowCommunityPosting !== true && process.env.PROMOTION_ALLOW_LIVE_REDDIT !== "true") {
        findings.push("Reddit community posting is disabled by policy");
      }
      if (!subreddit || /^u_[A-Za-z0-9_-]+$/.test(subreddit)) {
        findings.push("Reddit community post must target a non-profile subreddit");
      }
    } else if (mode !== "draft") {
      findings.push(`Unsupported Reddit mode: ${mode}`);
    }
  }

  for (const pattern of blockedClaimPatterns) {
    if (pattern.test(text)) {
      findings.push(`unsafe claim matched ${pattern}`);
    }
  }

  const lowerText = text.toLowerCase();
  const mentionsFullyLocal = lowerText.includes("fully local ai");
  const negatesFullyLocal = lowerText.includes("does not claim fully local ai");
  if (mentionsFullyLocal && !negatesFullyLocal) {
    findings.push("unsafe fully-local AI claim");
  }

  const mentionsChineseFullyLocal = text.includes("完全本地 AI");
  const negatesChineseFullyLocal = text.includes("不声称完全本地 AI");
  if (mentionsChineseFullyLocal && !negatesChineseFullyLocal) {
    findings.push("unsafe fully-local AI claim");
  }

  return findings;
}

function assertSafePost(post) {
  const findings = listReviewFindings(post);
  if (findings.length) throw new Error(`Blocked ${post.id}: ${findings.join("; ")}`);
}

function reviewedPost(post) {
  return {
    ...post,
    approval: {
      status: "approved",
      checkedAt: new Date().toISOString(),
      policyVersion: policy.version || "inline",
      mode: post.channel === "reddit" ? post.redditMode || "draft" : "direct"
    }
  };
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
      ...(post.title ? [`- Title: ${post.title}`] : []),
      ...(post.redditMode ? [`- Reddit mode: ${post.redditMode}`] : []),
      ...(post.subreddit ? [`- Subreddit: ${post.subreddit}`] : []),
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
      post: reviewedPost(post)
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
const maxQueueDay = Math.max(...queue.map((post) => post.day));

if (!dayOverride && day > maxQueueDay) {
  console.log(`Launch promotion queue complete; day ${day} is beyond configured day ${maxQueueDay}.`);
  process.exit(0);
}

const publishPosts = channelAllowlist.size
  ? posts.filter((post) => channelAllowlist.has(post.channel))
  : posts;

for (const post of publishPosts) assertSafePost(post);

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
