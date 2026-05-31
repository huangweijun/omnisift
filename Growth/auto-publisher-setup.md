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
- `reddit`: Reddit module/API only for communities where posting is allowed; otherwise route to a draft task.
- `linkedin`: LinkedIn page post or Buffer queue.
- `jike`: Notion/Google Sheet draft queue.
- `video-caption`: Notion/Google Sheet task for short video production.
- `producthunt-draft`: Notion/Google Sheet launch draft.
- `show-hn-draft`: Notion/Google Sheet launch draft.

If a platform does not provide an official API or approved integration, route the post to a draft task rather than simulating human browser activity.

## GitHub Configuration

Add repository secret:

- `PROMOTION_WEBHOOK_URL`: Make custom webhook URL.

Optional repository secret:

- `PROMOTION_WEBHOOK_API_KEY`: random shared secret for Make webhook verification.

Add repository variable:

- `PROMOTION_PUBLISH_MODE`: `webhook`

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

`publish_queue.mjs` blocks unsafe claims such as:

- unlimited usage
- lifetime pricing
- fully local AI claims unless explicitly negated

Keep platform credentials outside Git:

- Use GitHub Secrets for webhook URLs or API keys.
- Store account passwords and 2FA recovery codes in a password manager.
- Do not commit browser cookies, session exports, phone numbers, OTPs, or private identity data.

## Daily Schedule

The workflow runs every day at `01:30 UTC`.

Launch day is calculated from `PROMOTION_LAUNCH_START`.

For the first run, keep `PROMOTION_PUBLISH_MODE=dry-run`. After confirming the Make route works, switch to `webhook`.
