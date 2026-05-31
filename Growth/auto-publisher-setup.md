# OmniSift Auto Publisher Setup

Goal: generate launch posts automatically and send them to a compliant publishing tool. Do not use browser automation to disguise automated actions as human activity.

## Architecture

```text
Growth/queue/launch-week.json
  -> Growth/scripts/publish_queue.mjs
  -> GitHub Actions: Promotion Publisher
  -> dry-run artifact OR webhook publisher
  -> Buffer / Make / Zapier / n8n / official platform API
```

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

## Webhook Publishing

Use this when you have connected a compliant publisher.

Recommended low-friction options:

- Buffer: connect X, LinkedIn, Threads/Instagram if available; publish via Buffer integration or a Make/Zapier/n8n scenario.
- Make: create a custom webhook, then route by `post.channel`.
- Zapier: create a Catch Hook trigger, then route to social posting actions.
- n8n: create a webhook workflow, then use official integrations or platform APIs.

GitHub configuration:

1. Add repository secret:
   - `PROMOTION_WEBHOOK_URL`: webhook URL from Make/Zapier/n8n/Buffer bridge.
2. Add repository variable:
   - `PROMOTION_PUBLISH_MODE`: `webhook`
3. Optional repository variable:
   - `PROMOTION_LAUNCH_START`: `2026-05-31`
4. Run workflow manually once with:
   - `day`: `1`
   - `mode`: `webhook`

Webhook payload shape:

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

## Channel Routing

Suggested routes:

- `x`: X/Twitter publisher
- `threads`: Threads publisher
- `jike`: send to draft inbox or manual approval queue if no official automation exists
- `linkedin`: LinkedIn page publisher
- `video-caption`: store as short video caption task
- `producthunt-draft`: store as launch draft task
- `show-hn-draft`: store as launch draft task

If a platform does not provide an official API or approved integration, route the post to a draft task rather than simulating human browser activity.

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

For the first run, keep `PROMOTION_PUBLISH_MODE=dry-run`. After confirming the route works, switch to `webhook`.
