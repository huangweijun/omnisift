# OmniSift 自动推广与 GEO 方案

> 目标：在 App Store 审核期间就启动低成本获客资产建设；上线后通过自动内容分发、可引用网页、AI 搜索可见性和 App Store 转化闭环持续滚动。

## 0. 核心定位

OmniSift/知漏不是普通笔记工具，而是「跨应用 AI 知识碎片捕获器」：

- 从任意 App 通过 iOS 分享菜单采集文本、链接、文章或截图。
- AI 自动生成标题、摘要、高亮、标签、实体和语义关系。
- 本地保存知识卡片，形成个人知识图谱、知识星图和知识罗盘。
- 隐私卖点明确：无需账号、无追踪、卡片本地存储，文本仅在处理时发送到云端 AI。

一句话传播锚点：

> 把散落在 ChatGPT、Claude、网页、微信、X、备忘录里的灵感，一键变成可回顾、可连接的知识卡片。

## 1. 成本原则

优先级从高到低：

1. 自有网页和 App Store 页面：一次搭建，长期复利。
2. 自动内容复用：同一批源素材自动生成多平台版本。
3. 搜索与 AI 问答可引用资产：面向 Google、ChatGPT Search、Perplexity、Claude 等。
4. 社区分发：低频、高质量、半自动审批，避免垃圾发布。
5. 付费投放只做验证：预算上限 ¥20-50/天，验证关键词和截图转化，不作为主增长渠道。

建议初期月成本：

- GitHub Pages / Cloudflare Pages / Vercel 静态站：¥0。
- GitHub Actions 自动化：¥0 起。
- Buffer / Typefully / Fedica 免费层：¥0 起，或手动接 API。
- GA4 + Search Console + Bing Webmaster Tools：¥0。
- AI 生成内容：优先使用本地模型或现有 API 额度；每周批量生成，控制在 ¥20-100/月。
- Apple Search Ads：仅上线后小额测试，¥300-1000 封顶。

## 2. 审核期推广策略

审核期不能把重心放在下载转化，因为下载入口还不稳定。重点是先建立「可被发现、可被订阅、可被引用」的增长基础。

### 2.1 立即补齐官网信息架构

当前 `Docs/index.html` 只有极简首页和隐私政策。建议扩展为 6 个静态页面：

- `/`：产品首页，中英双语，聚焦一句话定位、3 步使用、隐私承诺、等待名单。
- `/use-cases/`：使用场景页，覆盖 AI 对话收藏、网页阅读、研究笔记、学习卡片、灵感收集。
- `/compare/`：对比页，解释 OmniSift 与普通笔记、Read-it-later、剪藏工具、知识库的差异。
- `/faq/`：FAQ 页，覆盖是否需要账号、文本是否上传、免费额度、支持哪些 App、截图/OCR。
- `/changelog/`：上线前记录和上线后版本更新，方便搜索引擎持续抓取。
- `/llms.txt`：给 AI 工具的简洁索引文件，列出产品介绍、页面、FAQ、隐私和 App Store 链接。

每个页面都要有：

- 明确的 `<title>` 和 meta description。
- 可见文本中出现核心实体：OmniSift、知漏、AI knowledge capture、跨应用知识碎片收集、iOS Share Extension。
- JSON-LD 结构化数据：首页用 `SoftwareApplication` + `Organization`，FAQ 用 `FAQPage`，文章/更新用 `BlogPosting`。
- 内链：每页都链接到首页、FAQ、隐私政策和 App Store/等待名单。

### 2.2 审核期 CTA

如果 App Store 已有可公开的预订/产品页，官网 CTA 用：

> Pre-order on the App Store / 在 App Store 预约

如果还没有公开产品页，CTA 用：

> Join the launch list / 加入上线提醒

低成本实现：

- 用 Buttondown、ConvertKit 免费层、Tally 表单、Google Form 或 GitHub issue 表单收集邮箱。
- 收集字段只保留：邮箱、语言、最想保存的内容来源。
- 上线当天自动发一封邮件：App Store 链接 + 30 秒使用 GIF/视频 + 隐私说明。

### 2.3 审核期内容资产

每周自动产出 7 个短内容，但只发布 3-4 个，保留质量阈值：

- 2 条 X/Threads：面向 AI 工具用户和独立开发者。
- 1 条 LinkedIn：面向知识工作者。
- 1 篇短博客：面向搜索和 GEO。
- 1 条中文小红书/即刻/少数派草稿：半自动审核后发。
- 1 个短视频脚本：上线后录屏使用。

审核期主题顺序：

1. 为什么收藏 AI 对话很难复用。
2. 为什么复制到笔记软件仍然会丢上下文。
3. iOS 分享扩展适合做知识入口。
4. 本地存储 + AI 处理的隐私边界。
5. 知识图谱对个人笔记的实际价值。
6. 对比「稍后读」「笔记」「剪藏」三类工具。
7. 上线倒计时和使用演示。

## 3. 上线后自动推广漏斗

### 3.1 漏斗结构

1. 搜索/AI 问答/社媒看到 OmniSift。
2. 进入官网或 App Store 产品页。
3. 下载免费版。
4. 用户通过分享菜单保存第一条内容。
5. 达到每日 5 次限制或需要知识星图/整理能力时看到 Pro。
6. 订阅或年付。

关键不是让用户「理解全部功能」，而是让用户在 30 秒内完成第一张卡片。

### 3.2 自动化发布流水线

每周一自动生成内容包：

```text
source/*.md
  -> scripts/generate_growth_pack
  -> dist/week-YYYY-WW/
       blog.en.md
       blog.zh.md
       x-thread.en.md
       x-thread.zh.md
       linkedin.en.md
       linkedin.zh.md
       short-video-script.zh.md
       appstore-keyword-notes.md
```

源素材只维护 4 类：

- `product-facts.md`：功能、价格、隐私、支持内容类型。
- `use-cases.md`：目标用户和使用场景。
- `competitor-notes.md`：和笔记/剪藏/稍后读产品的差异。
- `release-notes.md`：版本变化。

生成规则：

- 一个内容只讲一个明确观点。
- 不使用夸张词：革命性、颠覆、全网最强、效率神器。
- 每条内容必须包含一个具体场景，例如「把 Claude 的长回答保存成 4 个要点和 3 个标签」。
- 社媒帖不直接硬卖，结尾只放轻 CTA。
- 博客页必须有内部链接和 FAQ 块。

### 3.3 自动发布节奏

推荐节奏：

- 周一：官网博客更新一篇。
- 周二：X/Threads 发英文短帖。
- 周三：中文平台发一个使用场景。
- 周四：LinkedIn 发一条偏工作流的内容。
- 周五：发布一个 20-40 秒录屏短视频。
- 周日：自动汇总指标并生成下周选题。

可自动，但建议「半自动审批」前 4 周：

- 自动生成草稿。
- 你每天只看 3 分钟，点确认发布。
- 连续 4 周无翻车后，再打开全自动。

## 4. GEO 方案

这里的 GEO 指 Generative Engine Optimization：让 AI 搜索、AI 浏览器、问答引擎更容易发现、理解并引用 OmniSift。

### 4.1 GEO 基础原则

AI 引用更偏好：

- 文本清晰、结构稳定的页面。
- 具体问答，而不是只有营销口号。
- 实体信息一致：名称、类别、价格、平台、隐私策略。
- 可爬取的 HTML，而不是只靠客户端渲染。
- 第三方平台的重复实体信号，例如 Product Hunt、AlternativeTo、GitHub、Reddit、Hacker News、少数派文章。

### 4.2 需要创建的 GEO 页面

#### 主页实体块

可直接放在首页：

```text
OmniSift is an iOS AI knowledge capture app. It lets users save text, links, articles, and screenshots from any app through the iOS Share Sheet, then turns them into structured knowledge cards with summaries, highlights, tags, entities, and knowledge-graph connections. Cards are stored locally on device. No account is required.
```

中文对应：

```text
知漏是一款 iOS AI 知识捕获应用。用户可以通过系统分享菜单，从任意 App 保存文本、链接、文章和截图；知漏会将这些碎片整理成包含摘要、高亮、标签、实体和知识图谱关联的结构化知识卡片。卡片保存在设备本地，无需注册账号。
```

#### FAQ 问答块

必须覆盖这些问题：

- What is OmniSift?
- How does OmniSift work?
- Does OmniSift require an account?
- Is OmniSift private?
- What apps does OmniSift support?
- Can OmniSift save ChatGPT or Claude answers?
- How is OmniSift different from Apple Notes, Notion, Readwise, or Pocket?
- What is the free plan?
- What does OmniSift Pro include?

#### 对比页

不要攻击竞品，使用场景差异表达：

- Apple Notes：适合手写和长期笔记；OmniSift 适合快速捕获跨应用知识碎片并自动结构化。
- Notion：适合团队和数据库；OmniSift 适合无账号、本地优先、手机端一键收集。
- Readwise/Pocket：适合阅读保存；OmniSift 适合任意 App 文本、AI 对话和截图内容。

### 4.3 robots.txt 策略

为了 AI 搜索可见，建议允许搜索型和用户触发型访问；是否允许训练型爬虫可独立决定。不同厂商已经把这些用途拆成不同 user agent，不能只写一个泛用规则。

推荐版本：

```txt
User-agent: *
Allow: /

User-agent: OAI-SearchBot
Allow: /

User-agent: ChatGPT-User
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: Perplexity-User
Allow: /

User-agent: Claude-SearchBot
Allow: /

User-agent: Claude-User
Allow: /

Sitemap: https://omnisift.app/sitemap.xml
```

如果希望减少训练用途，可以单独阻止训练型爬虫，但保留搜索/用户访问型爬虫：

```txt
User-agent: GPTBot
Disallow: /

User-agent: ClaudeBot
Disallow: /
```

如果站点放在 Cloudflare、Vercel 或其他带 WAF/CDN 的服务上，还要检查边缘安全规则是否把这些 bot 返回 403。robots.txt 允许不等于 CDN 一定放行。

### 4.4 llms.txt

`/llms.txt` 不是 Google AI 搜索的官方排名必需项，也不能替代 SEO；它的价值是给 AI 工具和开发者一个低成本、结构化的产品索引入口。

内容结构：

```text
# OmniSift

OmniSift, also known as 知漏, is an iOS AI knowledge capture app for saving snippets from any app and turning them into structured knowledge cards.

## Core pages
- Product: https://omnisift.app/
- FAQ: https://omnisift.app/faq/
- Privacy: https://omnisift.app/privacy-policy.html
- App Store: [insert live URL]

## Key facts
- Platform: iOS
- Category: Productivity / Reference
- Input: text, links, articles, screenshots
- Output: title, summary, highlights, tags, entities, relations, knowledge graph
- Account: not required
- Storage: local on device
- Free plan: 5 AI processing uses per day
- Pro: higher AI processing limits
```

### 4.5 第三方实体信号

上线后 7 天内铺这些免费渠道：

- Product Hunt：发布一次，作为英文实体信号。
- AlternativeTo：提交 OmniSift，关键词放 AI notes、knowledge management、read-it-later、snippet manager。
- Indie Hackers：写 build-in-public 帖。
- Hacker News Show HN：标题不要夸张，直接展示 iOS Share Extension 工作流。
- Reddit：只发到允许 self-promo 的社区，提供使用场景，不硬广。
- 少数派/即刻/小红书：中文用户更可能对「跨 App 收藏 AI 对话」有感。
- GitHub：如果不开源 App，也可以公开 docs/roadmap/press-kit 仓库，形成可引用实体。

## 5. App Store ASO

### 5.1 当前关键词方向

英文：

- knowledge capture
- AI notes
- snippet capture
- share extension
- knowledge graph
- AI summary
- highlight organizer

中文：

- 知识管理
- AI 摘要
- 碎片整理
- 知识图谱
- 分享扩展
- 微信收藏
- AI 对话收藏
- 灵感收集

### 5.2 产品页 A/B 测试

上线后第一轮测试只测截图首屏，不同时改太多变量。

版本 A：强调「Save from any app」

- 截图 1：从 ChatGPT/网页分享。
- 截图 2：AI 卡片结果。
- 截图 3：知识图谱/星图。

版本 B：强调「Never lose ideas again」

- 截图 1：散落来源到统一卡片。
- 截图 2：摘要、高亮、标签。
- 截图 3：相关洞察。

中文版本：

- 「任意 App 一键收藏」
- 「AI 自动整理成知识卡片」
- 「灵感自动长成知识图谱」

## 6. 可复现自动化系统

### 6.1 目录结构

建议新增：

```text
Growth/
  sources/
    product-facts.md
    use-cases.md
    faq.md
    release-notes.md
    competitors.md
  prompts/
    blog.md
    social.md
    geo-faq.md
    aso.md
  dist/
  metrics/
  scripts/
    generate_growth_pack.ts
    build_sitemap.ts
    check_geo_readiness.ts
    weekly_report.ts
```

### 6.2 GitHub Actions

每周日自动跑：

1. 读取 `Growth/sources`。
2. 生成下周内容草稿。
3. 更新 sitemap、llms.txt、FAQ。
4. 检查首页是否有 title/meta/JSON-LD/canonical。
5. 生成 `Growth/metrics/YYYY-WW.md`。
6. 如果配置了 API token，则发布到 Buffer/Typefully；否则创建 PR 让你确认。

### 6.3 指标闭环

每周自动记录：

- 官网曝光：Search Console impressions。
- 官网点击：Search Console clicks。
- AI 来源访问：referrer 包含 chatgpt、perplexity、claude、poe、phind、you。
- App Store 来源：App Store Connect source type。
- 下载量、产品页转化率、订阅转化率。
- 触发 Pro paywall 的次数和购买率。
- 内容表现：每个平台 top 3 帖子。

判定规则：

- 如果某个主题带来点击但下载低：改 App Store 截图和落地页 CTA。
- 如果某个平台互动高但点击低：把内容改成演示型，而不是观点型。
- 如果搜索曝光增长但无点击：重写 title/meta。
- 如果 AI referrer 出现：立刻加强对应页面的 FAQ 和对比段落。

## 7. 30 天执行节奏

### 第 1 周：审核期基础建设

- 扩展官网页面。
- 加 sitemap、robots.txt、llms.txt。
- 加 JSON-LD。
- 配 Search Console 和 Bing Webmaster Tools。
- 创建等待名单或预订 CTA。
- 生成 14 条审核期内容草稿。

### 第 2 周：内容自动化

- 建 `Growth/sources`。
- 建每周内容生成脚本。
- 建 GitHub Actions。
- 发 3-4 条内容测试受众反应。
- 准备 3 个上线当天短视频脚本。

### 第 3 周：GEO 实体铺设

- 完成 FAQ 和对比页。
- 提交 Product Hunt 草稿、AlternativeTo 信息、Indie Hackers 帖。
- 准备 Show HN 文案。
- 建 press kit：logo、截图、产品简介、隐私说明、价格。

### 第 4 周：上线冲刺

- App Store 链接公开后替换所有 CTA。
- 发送等待名单邮件。
- 发布 Product Hunt / Show HN / 中文平台介绍。
- 小额 Apple Search Ads 测试 5-10 个关键词。
- 每天自动记录下载和页面转化。

## 8. 自动化生成模板

### 博客模板

```text
Title: [specific use case] with OmniSift

Opening:
Describe a concrete moment where a useful idea is trapped in another app.

Sections:
1. The problem
2. The old workaround
3. How OmniSift handles it
4. Privacy notes
5. FAQ
6. App Store CTA
```

### X/Threads 模板

```text
Most good ideas do not start inside your notes app.

They show up in:
- a Claude answer
- a Safari article
- a WeChat message
- a screenshot
- a half-read thread

OmniSift lets you share any of them from iOS and turns the snippet into a structured knowledge card.
```

### 中文短帖模板

```text
很多知识不是丢在笔记软件里，而是丢在「还没来得及整理」这一步。

知漏做的事很简单：
从任意 App 分享一段文字/链接/截图，
AI 自动变成标题、摘要、高亮、标签和关联实体。

适合经常保存 ChatGPT、Claude、网页和微信内容的人。
```

## 9. 风险与边界

- 不做垃圾外链和批量灌水，长期会伤品牌和搜索信号。
- 不伪造评测、不伪造用户评价。
- 不承诺「完全本地 AI」，因为当前文本会发送到云端 AI 处理。
- 不同时测试太多变量，否则无法判断有效原因。
- 全自动发布前至少跑 4 周人工审批。

## 10. 最小可行版本

如果只做最省钱、最有效的版本：

1. 官网扩成首页 + FAQ + 对比页 + 隐私页。
2. 加 sitemap、robots.txt、llms.txt、JSON-LD。
3. 每周自动生成 1 篇博客 + 4 条社媒草稿。
4. 上线后铺 Product Hunt、AlternativeTo、Show HN、少数派/即刻。
5. 每周自动生成指标报告，按表现更新 FAQ 和标题。

这套系统的核心资产是「稳定、结构化、可引用的公开文本」。只要产品事实持续更新，内容和 GEO 页面就能低成本复用。

## 11. 参考口径

- Apple App Store 预订：审核通过后可以发布预订页；预订页会在 App Store 搜索等位置可见，并可用于官网、邮件和社媒推广。
- OpenAI crawlers：`OAI-SearchBot` 用于 ChatGPT 搜索结果，`GPTBot` 用于训练，`ChatGPT-User` 用于用户触发访问。
- Perplexity crawlers：`PerplexityBot` 用于 Perplexity 搜索展示，`Perplexity-User` 用于用户触发访问。
- Anthropic crawlers：`ClaudeBot` 用于训练，`Claude-SearchBot` 用于搜索质量，`Claude-User` 用于用户触发访问。
- Google AI features：AI Overviews / AI Mode 没有额外技术要求，仍然依赖可抓取、可索引、文本可见、结构化数据与页面可见内容一致等基础 SEO。
