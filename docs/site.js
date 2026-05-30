(function () {
  var storageKey = "omnisift.language";
  var defaultLanguage = "en";

  var config = {
    appStoreUrl: "https://apps.apple.com/us/app/omnisift/id6773056945?uo=4"
  };

  var copy = {
    en: {
      "brand.name": "OmniSift",
      "brand.mark": "O",
      "nav.useCases": "Use cases",
      "nav.compare": "Compare",
      "nav.faq": "FAQ",
      "nav.privacy": "Privacy",
      "nav.launch": "Download",
      "footer.tagline": "Capture ideas, light your knowledge star map.",
      "footer.home": "Home",
      "footer.changelog": "Changelog",
      "footer.contact": "Contact",
      "app.pending": "Download on the App Store",
      "app.live": "Download on the App Store",
      "cta.launch": "See use cases",
      "cta.faq": "Read the FAQ",
      "cta.compare": "Compare workflows",

      "home.eyebrow": "Capture -> Star Map -> Compass",
      "home.title": "OmniSift",
      "home.hero": "Collect ideas from iOS apps, copied links, and screenshots. OmniSift turns each fragment into a card, lights up your knowledge star map, and points a compass toward what to explore next.",
      "home.proof.account": "No account required",
      "home.proof.local": "Cards stored locally",
      "home.proof.tracking": "No tracking or analytics",
      "home.workflow.kicker": "How it works",
      "home.workflow.title": "Collect fragments. Light constellations. Follow the next route.",
      "home.workflow.lead": "OmniSift is built for ideas that appear outside your notes app: AI answers, web paragraphs, chat messages, Xiaohongshu links, screenshots, and copied images.",
      "home.step1.title": "Capture without sorting first",
      "home.step2.title": "Cards light the star map",
      "home.step3.title": "The compass points forward",
      "home.starmap.kicker": "Knowledge star map",
      "home.starmap.title": "Your reading becomes visible.",
      "home.starmap.lead": "Each saved card is a star. Topics become constellations. More collected evidence lights more of the map, making patterns and gaps easier to see.",
      "home.starmap.capture.title": "Fast collection",
      "home.starmap.capture.body": "Share text, articles, screenshots, copied images, and copied Xiaohongshu links without manually filing them first.",
      "home.starmap.organize.title": "Topic organization",
      "home.starmap.organize.body": "Use AI to merge, rename, and clean topic structures so the map stays navigable as it grows.",
      "home.starmap.compass.title": "Compass guidance",
      "home.starmap.compass.body": "Summarize lit constellations, reveal dim areas, and get concrete exploration routes.",
      "home.positioning.kicker": "Positioning",
      "home.positioning.title": "Not another place to type notes.",
      "home.positioning.lead": "OmniSift starts where ideas actually show up: inside ChatGPT, Claude, Safari, WeChat, Xiaohongshu, X, Notes, and screenshots. It focuses on capture, structure, visibility, and next-step guidance.",
      "home.privacy.kicker": "Privacy boundary",
      "home.privacy.title": "Local-first storage, clear cloud processing.",
      "home.privacy.lead": "OmniSift does not claim fully local AI. Text you share is sent to cloud AI for processing, and the resulting cards are stored on your device.",
      "home.privacy.account.title": "No account required",
      "home.privacy.account.body": "Start collecting without sign-in, onboarding accounts, or a hosted workspace.",
      "home.privacy.tracking.title": "No tracking",
      "home.privacy.tracking.body": "OmniSift does not use analytics services, advertising frameworks, or behavioral tracking.",
      "home.privacy.local.title": "Local card storage",
      "home.privacy.local.body": "Processed knowledge cards are stored locally on device. Text is sent to cloud AI only for processing.",
      "home.pricing.kicker": "Pricing",
      "home.pricing.title": "Free to start, Pro for heavier capture.",
      "home.pricing.lead": "OmniSift is live as a free App Store download. Pro availability is handled through App Store subscriptions.",
      "home.pricing.free": "Free",
      "home.pricing.pro": "OmniSift Pro",

      "use.hero.kicker": "Use cases",
      "use.hero.title": "For the moments when an idea appears outside your notes app.",
      "use.hero.lead": "OmniSift is designed for knowledge workers, students, researchers, founders, and curious readers who collect useful fragments across many iOS apps.",
      "use.label.ai": "AI",
      "use.label.web": "Web",
      "use.label.ocr": "OCR",
      "use.label.study": "Study",
      "use.label.research": "Research",
      "use.label.ideas": "Ideas",
      "use.ai.title": "Save ChatGPT and Claude answers",
      "use.web.title": "Capture web reading",
      "use.ocr.title": "Turn screenshots into knowledge",
      "use.study.title": "Build study cards from highlights",
      "use.research.title": "Connect research fragments",
      "use.ideas.title": "Keep small ideas from disappearing",
      "use.workflow.kicker": "Workflow fit",
      "use.workflow.title": "Best when capture needs to be faster than organization.",
      "use.workflow.lead": "If you already know you want to write a full page, use your note app. If you found a fragment that might matter later, send it to OmniSift.",

      "compare.hero.kicker": "Compare",
      "compare.hero.title": "Different tools fit different parts of the knowledge workflow.",
      "compare.hero.lead": "OmniSift is not trying to replace every note, reading, or workspace tool. It focuses on one narrow job: fast cross-app capture on iOS, followed by AI-generated structure.",
      "compare.table.tool": "Tool",
      "compare.table.best": "Best fit",
      "compare.table.diff": "Where OmniSift differs",
      "compare.notes.best": "Writing notes, quick personal lists, sketches, and long-term Apple ecosystem storage.",
      "compare.notes.diff": "OmniSift is for fast capture from other apps and automatic card structure: summary, highlights, tags, entities, and relations.",
      "compare.notion.best": "Databases, team workspaces, project docs, and highly customizable pages.",
      "compare.notion.diff": "OmniSift avoids account-first workspace setup and focuses on mobile Share Sheet capture with local card storage.",
      "compare.readwise.best": "Reader highlights, review workflows, and resurfacing saved reading highlights.",
      "compare.readwise.diff": "OmniSift accepts broader iOS inputs, including AI answers, plain text snippets, links, articles, and screenshots.",
      "compare.pocket.best": "Saving articles and links to read later.",
      "compare.pocket.diff": "OmniSift is less about a reading queue and more about turning a captured fragment into a structured knowledge card.",
      "compare.positioning.kicker": "Positioning",
      "compare.positioning.title": "Use OmniSift when the input is scattered and the structure is missing.",
      "compare.positioning.lead": "The ideal OmniSift moment is not a blank page. It is a sentence in a chat, a useful paragraph in a browser, a screenshot from an app, or an AI answer you do not want to lose.",
      "compare.bullet.capture": "Cross-app capture through the iOS Share Sheet.",
      "compare.bullet.structure": "AI-generated title, summary, highlights, tags, entities, and semantic relations.",
      "compare.bullet.privacy": "Local card storage, no account requirement, no analytics tracking.",

      "faq.hero.kicker": "FAQ",
      "faq.hero.title": "Questions AI search engines and real users both ask.",
      "faq.hero.lead": "Clear answers about what OmniSift does, where data goes, and how the first release is priced.",
      "faq.q.what": "What is OmniSift?",
      "faq.q.how": "How does OmniSift work?",
      "faq.q.account": "Does OmniSift require an account?",
      "faq.q.private": "Is OmniSift private?",
      "faq.q.apps": "What apps does OmniSift support?",
      "faq.q.ai": "Can OmniSift save ChatGPT or Claude answers?",
      "faq.q.different": "How is OmniSift different from Apple Notes, Notion, Readwise, or Pocket?",
      "faq.q.free": "What is the free plan?",
      "faq.q.pro": "What does OmniSift Pro include?",

      "privacy.kicker": "Privacy Policy",
      "privacy.title": "Privacy Policy",
      "privacy.effective": "OmniSift - Effective Date: 2026-05-21",

      "changelog.kicker": "Changelog",
      "changelog.title": "Launch notes for OmniSift.",
      "changelog.lead": "This page records public product updates so users, search engines, and AI answer engines can follow what changed over time.",
      "changelog.v1.title": "v1.0 is live on the App Store",
      "changelog.v1.body": "OmniSift v1.0 is now available as a free iOS download on the App Store. The first version focuses on Share Extension capture, clipboard-assisted collection, AI-powered knowledge cards, local card storage, a star-map view, and a knowledge compass.",
      "changelog.v1.capture": "Capture text, links, articles, screenshots, copied images, and copied Xiaohongshu links with confirmation.",
      "changelog.v1.ai": "Generate card titles, summaries, highlights, tags, entities, semantic relations, and readable Markdown originals when source text is available.",
      "changelog.v1.graph": "Browse saved cards, related insights, topic constellations, star maps, and compass guidance.",
      "changelog.v1.pricing": "Free plan: 5 AI processing uses per day. Pro is designed for 50 uses per day with first-release pricing planned at ¥12/month or ¥68/year when available through App Store subscriptions.",

      "privacy.h1": "1. Introduction",
      "privacy.h2": "2. Data We Collect",
      "privacy.h3": "3. How We Process Your Data",
      "privacy.h4": "4. Data Storage",
      "privacy.h5": "5. No Tracking or Analytics",
      "privacy.h6": "6. Subscriptions & Payments",
      "privacy.h7": "7. Third-Party Services",
      "privacy.h8": "8. Data Deletion",
      "privacy.h9": "9. Children's Privacy",
      "privacy.h10": "10. Changes to This Policy",
      "privacy.h11": "11. Contact"
    },
    zh: {
      "brand.name": "知漏",
      "brand.mark": "知",
      "nav.useCases": "使用场景",
      "nav.compare": "对比",
      "nav.faq": "常见问题",
      "nav.privacy": "隐私",
      "nav.launch": "下载",
      "footer.tagline": "收集想法，点亮你的知识星图。",
      "footer.home": "首页",
      "footer.changelog": "更新记录",
      "footer.contact": "联系",
      "app.pending": "在 App Store 下载",
      "app.live": "在 App Store 下载",
      "cta.launch": "查看使用场景",
      "cta.faq": "查看常见问题",
      "cta.compare": "对比工作流",

      "home.eyebrow": "采集 -> 星图 -> 罗盘",
      "home.title": "知漏",
      "home.hero": "从 iOS App、复制链接和截图里收集想法。知漏会把每个片段变成卡片，点亮你的知识星图，并用罗盘提示下一步该探索什么。",
      "home.proof.account": "无需账号",
      "home.proof.local": "卡片本地存储",
      "home.proof.tracking": "无追踪与分析",
      "home.workflow.kicker": "使用方式",
      "home.workflow.title": "收集碎片，点亮星座，跟随下一条路线。",
      "home.workflow.lead": "知漏适合保存那些不在笔记软件里出现的想法：AI 回答、网页段落、聊天消息、小红书链接、截图和复制图片。",
      "home.step1.title": "先采集，不急着整理",
      "home.step2.title": "卡片点亮星图",
      "home.step3.title": "罗盘指向下一步",
      "home.starmap.kicker": "知识星图",
      "home.starmap.title": "你的阅读会变得可见。",
      "home.starmap.lead": "每张卡片都是一颗星，主题会形成星座。收集的证据越多，星图越亮，模式和缺口也越容易被看见。",
      "home.starmap.capture.title": "快速收集",
      "home.starmap.capture.body": "通过分享菜单、复制图片和复制小红书链接收集内容，不需要先手动归档。",
      "home.starmap.organize.title": "主题整理",
      "home.starmap.organize.body": "用 AI 合并、重命名并清理主题结构，让星图在变大后依然清晰。",
      "home.starmap.compass.title": "罗盘指引",
      "home.starmap.compass.body": "总结已点亮星座，发现暗区，并给出具体探索路线。",
      "home.positioning.kicker": "产品定位",
      "home.positioning.title": "不是另一个让你手写笔记的地方。",
      "home.positioning.lead": "知漏从想法真正出现的地方开始：ChatGPT、Claude、Safari、微信、小红书、X、备忘录和截图。它聚焦采集、结构化、可视化和下一步指引。",
      "home.privacy.kicker": "隐私边界",
      "home.privacy.title": "本地优先存储，清晰说明云端处理。",
      "home.privacy.lead": "知漏不声称 AI 完全本地运行。你分享的文本会发送到云端 AI 处理，生成的卡片保存在设备本地。",
      "home.privacy.account.title": "无需账号",
      "home.privacy.account.body": "无需登录、注册或创建云端工作区，即可开始收集。",
      "home.privacy.tracking.title": "无追踪",
      "home.privacy.tracking.body": "知漏不使用分析服务、广告框架或行为追踪技术。",
      "home.privacy.local.title": "卡片本地存储",
      "home.privacy.local.body": "处理后的知识卡片保存在设备本地；文本仅在处理时发送到云端 AI。",
      "home.pricing.kicker": "定价",
      "home.pricing.title": "免费开始，高频收集可升级 Pro。",
      "home.pricing.lead": "知漏已作为免费 iOS App 在 App Store 上线。专业版可用性由 App Store 订阅处理。",
      "home.pricing.free": "免费版",
      "home.pricing.pro": "知漏专业版",

      "use.hero.kicker": "使用场景",
      "use.hero.title": "适合那些想法出现在笔记软件之外的时刻。",
      "use.hero.lead": "知漏面向知识工作者、学生、研究者、创业者和好奇的读者，他们经常在多个 iOS App 中收集有用片段。",
      "use.label.ai": "AI",
      "use.label.web": "网页",
      "use.label.ocr": "OCR",
      "use.label.study": "学习",
      "use.label.research": "研究",
      "use.label.ideas": "灵感",
      "use.ai.title": "保存 ChatGPT 和 Claude 回答",
      "use.web.title": "捕获网页阅读片段",
      "use.ocr.title": "把截图变成知识",
      "use.study.title": "从高亮生成学习卡片",
      "use.research.title": "连接研究碎片",
      "use.ideas.title": "别让小想法消失",
      "use.workflow.kicker": "工作流匹配",
      "use.workflow.title": "当捕获必须比整理更快时，知漏最合适。",
      "use.workflow.lead": "如果你已经知道要写一整页内容，用笔记软件。如果只是看到一个以后可能有用的片段，把它发送到知漏。",

      "compare.hero.kicker": "对比",
      "compare.hero.title": "不同工具适合知识工作流的不同阶段。",
      "compare.hero.lead": "知漏不试图替代所有笔记、阅读或工作区工具。它只专注一件事：在 iOS 上快速跨 App 捕获，然后用 AI 生成结构。",
      "compare.table.tool": "工具",
      "compare.table.best": "适合场景",
      "compare.table.diff": "知漏的差异",
      "compare.notes.best": "书写笔记、快速个人清单、草图，以及 Apple 生态内的长期存储。",
      "compare.notes.diff": "知漏用于从其他 App 快速捕获，并自动生成卡片结构：摘要、高亮、标签、实体和关系。",
      "compare.notion.best": "数据库、团队工作区、项目文档和高度自定义页面。",
      "compare.notion.diff": "知漏不从账号和工作区开始，而是聚焦移动端分享菜单捕获和本地卡片存储。",
      "compare.readwise.best": "阅读高亮、复习工作流和重新浮现已保存的阅读摘录。",
      "compare.readwise.diff": "知漏接受更广泛的 iOS 输入，包括 AI 回答、普通文本片段、链接、文章和截图。",
      "compare.pocket.best": "保存文章和链接，稍后阅读。",
      "compare.pocket.diff": "知漏不是阅读队列，更关注把捕获到的片段变成结构化知识卡片。",
      "compare.positioning.kicker": "产品定位",
      "compare.positioning.title": "当输入很分散、结构还不存在时，使用知漏。",
      "compare.positioning.lead": "理想的知漏时刻不是空白页，而是聊天里的一句话、浏览器里的有用段落、某个 App 的截图，或一段不想丢掉的 AI 回答。",
      "compare.bullet.capture": "通过 iOS 分享菜单跨 App 捕获。",
      "compare.bullet.structure": "AI 自动生成标题、摘要、高亮、标签、实体和语义关系。",
      "compare.bullet.privacy": "卡片本地存储、无需账号、无分析追踪。",

      "faq.hero.kicker": "常见问题",
      "faq.hero.title": "用户和 AI 搜索引擎都会问的问题。",
      "faq.hero.lead": "清晰说明知漏做什么、数据去哪里、首发版本如何定价。",
      "faq.q.what": "知漏是什么？",
      "faq.q.how": "知漏如何工作？",
      "faq.q.account": "知漏需要账号吗？",
      "faq.q.private": "知漏是否注重隐私？",
      "faq.q.apps": "知漏支持哪些 App？",
      "faq.q.ai": "知漏可以保存 ChatGPT 或 Claude 的回答吗？",
      "faq.q.different": "知漏与 Apple Notes、Notion、Readwise、Pocket 有什么不同？",
      "faq.q.free": "免费版是什么？",
      "faq.q.pro": "知漏专业版包含什么？",

      "privacy.kicker": "隐私政策",
      "privacy.title": "隐私政策",
      "privacy.effective": "知漏 - 生效日期：2026-05-21",

      "changelog.kicker": "更新记录",
      "changelog.title": "知漏上线记录。",
      "changelog.lead": "这里记录公开产品更新，方便用户、搜索引擎和 AI 问答引擎理解产品变化。",
      "changelog.v1.title": "v1.0 已在 App Store 上线",
      "changelog.v1.body": "知漏 v1.0 已作为免费 iOS App 在 App Store 上线。首发版本聚焦分享扩展采集、剪贴板辅助收集、AI 知识卡片、本地存储、星图视图和知识罗盘。",
      "changelog.v1.capture": "通过分享菜单采集文本、链接、文章、截图，也可确认后收集复制图片和小红书链接。",
      "changelog.v1.ai": "使用云端 AI 生成标题、摘要、高亮、标签、实体、语义关系；原文可读时整理为 Markdown。",
      "changelog.v1.graph": "浏览已保存卡片、关联洞察、主题星座、知识星图和罗盘指引。",
      "changelog.v1.pricing": "免费版每日 5 次 AI 处理。专业版设计为每日 50 次，App Store 订阅可用后首发计划价格为 ¥12/月或 ¥68/年。",

      "privacy.h1": "1. 简介",
      "privacy.h2": "2. 我们收集的数据",
      "privacy.h3": "3. 数据处理方式",
      "privacy.h4": "4. 数据存储",
      "privacy.h5": "5. 无追踪或分析",
      "privacy.h6": "6. 订阅与支付",
      "privacy.h7": "7. 第三方服务",
      "privacy.h8": "8. 数据删除",
      "privacy.h9": "9. 儿童隐私",
      "privacy.h10": "10. 政策变更",
      "privacy.h11": "11. 联系方式"
    }
  };

  function currentLanguage() {
    return localStorage.getItem(storageKey) || defaultLanguage;
  }

  function setLanguage(language) {
    var lang = language === "zh" ? "zh" : "en";
    localStorage.setItem(storageKey, lang);
    document.documentElement.dataset.lang = lang;
    document.documentElement.lang = lang === "zh" ? "zh-Hans" : "en";

    document.querySelectorAll("[data-i18n]").forEach(function (node) {
      var key = node.getAttribute("data-i18n");
      if (copy[lang][key]) {
        node.textContent = copy[lang][key];
      }
    });

    document.querySelectorAll("[data-lang-option]").forEach(function (button) {
      button.setAttribute("aria-pressed", String(button.getAttribute("data-lang-option") === lang));
    });

    applyAppStoreLinks(lang);
  }

  function applyAppStoreLinks(lang) {
    var language = lang || currentLanguage();
    var links = document.querySelectorAll("[data-app-store-link]");
    links.forEach(function (link) {
      if (config.appStoreUrl) {
        link.setAttribute("href", config.appStoreUrl);
        link.classList.remove("is-pending");
        link.removeAttribute("aria-disabled");
        var liveKey = link.getAttribute("data-app-store-live-key") || "app.live";
        link.textContent = copy[language][liveKey] || copy[language]["app.live"];
      } else {
        link.setAttribute("href", "mailto:omnisift.app@gmail.com?subject=OmniSift%20launch%20notice");
        link.classList.add("is-pending");
        link.setAttribute("aria-disabled", "true");
        link.textContent = copy[language]["app.pending"];
      }
    });
  }

  function bindLanguageControls() {
    document.querySelectorAll("[data-lang-option]").forEach(function (button) {
      button.addEventListener("click", function () {
        setLanguage(button.getAttribute("data-lang-option"));
      });
    });
  }

  function init() {
    bindLanguageControls();
    setLanguage(currentLanguage());
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
