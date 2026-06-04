# OmniSift Make Auto Publisher Setup

Goal: generate launch posts automatically and send them to Make for compliant publishing. Do not use browser automation to disguise automated actions as human activity.

## Architecture

```text
Growth/queue/launch-week.json
  -> Growth/scripts/publish_queue.mjs
  -> GitHub Actions: Promotion Publisher
  -> dry-run artifact OR Make webhook
  -> Make router
  -> Buffer / Reddit / LinkedIn / Notion / draft queues / official platform APIs
```

## Recommended Publisher

Use Make first.

Make is the default for OmniSift because it is easier to operate than n8n, cheaper to start than Zapier, and flexible enough to route by `post.channel`.

Use Buffer as a publishing layer behind Make when a social platform is easier to connect through Buffer than directly through Make.

## Default Safe Mode

The workflow is dry-run by default. It generates `Growth/outbox/day-<n>.md` and uploads it as a GitHub Actions artifact.

Manual dry run:

```bash
PROMOTION_DAY=1 node Growth/scripts/publish_queue.mjs
```

Manual GitHub Actions run:

1. Open GitHub repo.
2. Go to Actions -> Promotion Publisher.
3. Click Run workflow.
4. Set:
   - `day`: `1`, `2`, `3`, `4`, or `5`
   - `mode`: `dry-run`
5. Download the `omnisift-promotion-outbox` artifact.

## Make Scenario Setup

Create one Make scenario:

```text
Custom webhook
  -> Router
  -> route: post.channel = x
  -> route: post.channel = threads
  -> route: post.channel = reddit
  -> route: post.channel = linkedin
  -> route: post.channel = jike
  -> route: post.channel = video-caption
  -> route: post.channel = producthunt-draft
  -> route: post.channel = show-hn-draft
```

Webhook module:

1. Create a new Make scenario.
2. Add `Webhooks -> Custom webhook`.
3. Name it `omnisift-promotion`.
4. Copy the generated webhook URL.
5. Click `Run once`.
6. Trigger a GitHub Actions dry webhook run or local test so Make can detect the payload fields.
7. Add a `Router` module after the webhook.
8. Add one route per channel.

Recommended channel actions:

- `x`: Buffer queue or X module/API.
- `threads`: Buffer queue if available on the connected Buffer account.
- `reddit`: use Make's verified Reddit app to auto-post to the owner profile subreddit first. Do not auto-post to third-party communities unless their rules and account eligibility are explicitly confirmed.
- `linkedin`: LinkedIn page post or Buffer queue.
- `jike`: Notion/Google Sheet draft queue.
- `video-caption`: Notion/Google Sheet task for short video production.
- `producthunt-draft`: Notion/Google Sheet launch draft.
- `show-hn-draft`: Notion/Google Sheet launch draft.

If a platform does not provide an official API or approved integration, route the post to a draft task rather than simulating human browser activity.

## Reddit Route

Buffer does not expose Reddit as a connectable channel in the current Buffer account, so route Reddit through Make instead.

Safe autopilot version:

```text
Custom webhook
  -> Router
  -> filter: post.channel = reddit
  -> Data Store: create "published/draft audit" row
  -> Reddit: submit a self post to the owner profile subreddit
```

Map these fields:

- Subreddit: `post.subreddit` (`u_InterestingEye6675` for the current owner profile)
- Title: `post.title`
- Body: `post.text`
- Kind: `post.kind` (`self`)
- Mode: `post.redditMode`
- Source id: `post.id`

The current safe live Reddit mode is `redditMode=profile`. The publisher permits profile posting only when `post.subreddit` matches `Growth/promotion-policy.json`.

When moving from profile posting to community posting, update the policy and Make route only after the subreddit is chosen and its rules allow the post:

- Kind: `self`
- Subreddit: the approved subreddit name, without `/r/`
- Title: `post.title`
- Text: `post.text`

The local publisher blocks community Reddit posts unless `PROMOTION_ALLOW_LIVE_REDDIT=true` is set explicitly or `allowCommunityPosting` is enabled in the promotion policy.

## GitHub Configuration

Add repository secret:

- `PROMOTION_WEBHOOK_URL`: Make custom webhook URL.

Optional repository secret:

- `PROMOTION_WEBHOOK_API_KEY`: random shared secret for Make webhook verification.

Add repository variable:

- `PROMOTION_PUBLISH_MODE`: `webhook`
- `PROMOTION_CHANNELS`: comma-separated channels that may be sent to the webhook, for example `x`

Optional repository variable:

- `PROMOTION_LAUNCH_START`: `2026-05-31`

Run workflow manually once with:

- `day`: `1`
- `mode`: `webhook`

## Optional Make API Key Check

If you set `PROMOTION_WEBHOOK_API_KEY`, add a filter immediately after the webhook:

```text
Header x-make-apikey equals your secret value
```

The publisher sends the key in the `x-make-apikey` header.

If the header is missing or wrong, Make should stop the scenario before the router.

## Webhook Payload Shape

```json
{
  "product": "OmniSift",
  "source": "github-actions",
  "post": {
    "id": "launch-day1-x",
    "day": 1,
    "channel": "x",
    "language": "en",
    "text": "..."
  }
}
```

## Safety Checks

`publish_queue.mjs` blocks unsafe claims and risky publishing states such as:

- unlimited usage
- lifetime pricing
- fully local AI claims unless explicitly negated
- X posts over 280 characters
- Reddit posts without a title
- Reddit titles over 300 characters
- Reddit community publishing unless explicitly enabled after subreddit rules are confirmed
- Reddit profile publishing to any profile other than the policy-approved owner profile

`PROMOTION_CHANNELS` should stay narrow until each Make route is connected to an official platform integration or a draft/audit queue. OmniSift currently uses `x,reddit`.

Keep platform credentials outside Git:

- Use GitHub Secrets for webhook URLs or API keys.
- Store account passwords and 2FA recovery codes in a password manager.
- Do not commit browser cookies, session exports, phone numbers, OTPs, or private identity data.

## Daily Schedule

The workflow runs every day at `01:30 UTC`.

Launch day is calculated from `PROMOTION_LAUNCH_START`.

Scheduled runs stop publishing automatically after the last configured queue day. Use a manual `PROMOTION_DAY` override only when intentionally replaying a day; replaying an X post too soon can be rejected by Buffer as a duplicate.

For the first run, keep `PROMOTION_PUBLISH_MODE=dry-run`. After confirming the Make route works, switch to `webhook`.
