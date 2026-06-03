import React from 'react';
import {
  AbsoluteFill,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {Audio} from '@remotion/media';

type DemoCard = {
  title: string;
  highlight: string;
  summary: string;
  sourceApp: string;
  sourceTitle: string;
  sourceURL?: string;
  topics: string[];
  keywords: string[];
  entities: string[];
  relations: string[];
  confidence: number;
  age: string;
  method: 'Web' | 'Text' | 'OCR';
  extraction: 'Full' | 'Text' | 'Image OCR';
  accent: string;
};

type ScreenName = 'capture' | 'share' | 'processing' | 'library' | 'detail' | 'map' | 'compass' | 'final';

const colors = {
  ink: '#111827',
  sub: '#667085',
  tertiary: '#98a2b3',
  paper: '#f7f5ef',
  panel: '#ffffff',
  line: '#e4e7ec',
  teal: '#00a88f',
  blue: '#2f72ff',
  orange: '#f5a524',
  coral: '#ff665c',
  purple: '#7357d8',
  dark: '#07111f',
  green: '#12b76a',
};

const demoCards: DemoCard[] = [
  {
    title: 'AI reading workflow',
    highlight: 'Capture first, organize second. The key is removing friction at the moment an idea appears.',
    summary:
      'Notes from an AI reading workflow that turns saved paragraphs into searchable cards with topics and entities.',
    sourceApp: 'ChatGPT',
    sourceTitle: 'Research workflow conversation',
    topics: ['AI Research', 'Knowledge Capture'],
    keywords: ['capture', 'summary', 'tags'],
    entities: ['ChatGPT', 'Knowledge Graph', 'OmniSift'],
    relations: ['AI summaries reduce review time', 'Knowledge Graph connects recurring concepts'],
    confidence: 0.88,
    age: 'Just now',
    method: 'Text',
    extraction: 'Text',
    accent: colors.teal,
  },
  {
    title: 'SwiftData migration checklist',
    highlight:
      'Keep lightweight migrations boring, test the shared container path, and ship with one obvious rollback story.',
    summary:
      'A compact checklist for making SwiftData changes safer when the main app and Share Extension share the same store.',
    sourceApp: 'Safari',
    sourceTitle: 'SwiftData migration notes',
    sourceURL: 'developer.apple.com/documentation/swiftdata',
    topics: ['iOS Architecture', 'Persistence'],
    keywords: ['SwiftData', 'migration', 'App Group'],
    entities: ['SwiftData', 'App Group', 'Share Extension'],
    relations: ['SwiftData requires a stable migration plan', 'Share Extension reads the shared container'],
    confidence: 0.91,
    age: '18 min ago',
    method: 'Web',
    extraction: 'Full',
    accent: colors.blue,
  },
  {
    title: 'Screenshot OCR idea capture',
    highlight: 'Screenshots are often the fallback when text selection or webpage extraction is not available.',
    summary:
      'A capture pattern for saving images first, extracting text, and attaching source context when possible.',
    sourceApp: 'Photos',
    sourceTitle: 'OCR capture note',
    topics: ['Capture Methods', 'OCR'],
    keywords: ['screenshot', 'OCR', 'fallback'],
    entities: ['Vision', 'Screenshot', 'Share Sheet'],
    relations: ['OCR converts images into reviewable cards', 'Share Sheet keeps capture cross-app'],
    confidence: 0.81,
    age: '1 hr ago',
    method: 'OCR',
    extraction: 'Image OCR',
    accent: colors.coral,
  },
  {
    title: 'Pricing and usage limits',
    highlight: 'Free users need enough daily value to form a habit; Pro should be for heavier capture.',
    summary: 'A launch pricing note comparing free daily AI processing with a lightweight Pro subscription.',
    sourceApp: 'Notes',
    sourceTitle: 'Launch plan',
    topics: ['Product Strategy', 'Subscriptions'],
    keywords: ['pricing', 'free tier', 'Pro'],
    entities: ['RevenueCat', 'App Store', 'OmniSift Pro'],
    relations: ['RevenueCat maps products to Pro entitlement', 'Free tier supports habit formation'],
    confidence: 0.84,
    age: '2 hrs ago',
    method: 'Text',
    extraction: 'Text',
    accent: colors.orange,
  },
];

const clamp = {
  extrapolateLeft: 'clamp' as const,
  extrapolateRight: 'clamp' as const,
};

const seconds = (value: number, fps: number) => Math.round(value * fps);
const t = (frame: number, fps: number) => frame / fps;
const fade = (frame: number, fps: number, from: number, to: number) =>
  interpolate(frame, [seconds(from, fps), seconds(to, fps)], [0, 1], clamp);
const slideY = (frame: number, fps: number, from: number, to: number, distance: number) =>
  interpolate(frame, [seconds(from, fps), seconds(to, fps)], [distance, 0], clamp);
const local = (globalFrame: number, fps: number, fromSeconds: number) =>
  globalFrame - seconds(fromSeconds, fps);

export const OmniSiftPromo: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const current = t(frame, fps);
  const screen = activeScreen(current);
  const finalOpacity = fade(frame, fps, 28.8, 29.35);

  return (
    <AbsoluteFill
      style={{
        background: '#fbf8f1',
        color: colors.ink,
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", Helvetica, Arial, sans-serif',
        overflow: 'hidden',
      }}
    >
      <Audio
        src={staticFile('pulse.wav')}
        loop
        volume={(audioFrame) =>
          interpolate(audioFrame, [0, seconds(1, fps), seconds(28.8, fps), seconds(30, fps)], [0, 0.28, 0.28, 0], clamp)
        }
      />
      <SceneBackdrop />
      <BrandHeader />
      <Narration current={current} />
      <FloatingSourcePanels current={current} />
      <PhoneFrame screen={screen} current={current} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          opacity: finalOpacity,
          pointerEvents: 'none',
          zIndex: 60,
        }}
      >
        <FinalCard />
      </div>
    </AbsoluteFill>
  );
};

const activeScreen = (current: number): ScreenName => {
  if (current < 3.6) return 'capture';
  if (current < 7.5) return 'share';
  if (current < 11.5) return 'processing';
  if (current < 16.5) return 'library';
  if (current < 21) return 'detail';
  if (current < 25.8) return 'map';
  if (current < 29) return 'compass';
  return 'final';
};

const SceneBackdrop: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const drift = interpolate(frame, [0, seconds(30, fps)], [-32, 36], clamp);
  return (
    <>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'radial-gradient(circle at 18% 12%, rgba(0,168,143,0.16), transparent 28%), radial-gradient(circle at 78% 18%, rgba(47,114,255,0.12), transparent 25%), radial-gradient(circle at 32% 82%, rgba(245,165,36,0.16), transparent 28%), linear-gradient(145deg, #fffaf2 0%, #edf7f5 52%, #f6f1ff 100%)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: -230,
          top: 345 + drift,
          width: 1500,
          height: 1500,
          borderRadius: '50%',
          border: '1px solid rgba(17,24,39,0.06)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 140,
          top: 660 - drift * 0.5,
          width: 800,
          height: 800,
          borderRadius: '50%',
          border: '1px solid rgba(0,168,143,0.11)',
        }}
      />
    </>
  );
};

const BrandHeader: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      left: 68,
      right: 68,
      top: 62,
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      zIndex: 5,
    }}
  >
    <div style={{display: 'flex', alignItems: 'center', gap: 16}}>
      <Img
        src={staticFile('app-icon.png')}
        style={{
          width: 58,
          height: 58,
          borderRadius: 15,
          boxShadow: '0 16px 34px rgba(17,24,39,0.16)',
        }}
      />
      <div>
        <div style={{fontSize: 31, fontWeight: 880}}>OmniSift</div>
        <div style={{fontSize: 18, color: colors.sub, marginTop: 1}}>知漏</div>
      </div>
    </div>
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        fontSize: 18,
        fontWeight: 750,
        color: colors.teal,
        padding: '12px 16px',
        borderRadius: 24,
        background: 'rgba(255,255,255,0.7)',
        border: '1px solid rgba(17,24,39,0.08)',
      }}
    >
      <span>iOS</span>
      <span style={{color: colors.tertiary}}>30s demo</span>
    </div>
  </div>
);

const narration = [
  {
    from: 0,
    to: 3.6,
    kicker: '跨应用捕获',
    title: '灵感出现时，先收下来',
    body: '从网页、AI 对话、备忘录或截图里，保存真正有用的那一段。',
  },
  {
    from: 3.6,
    to: 7.5,
    kicker: 'Share Extension',
    title: '分享进 OmniSift，不先手动分类',
    body: '预览来源、链接和正文，确认后保存。',
  },
  {
    from: 7.5,
    to: 11.5,
    kicker: 'AI 知识蒸馏',
    title: '碎片变成结构化卡片',
    body: '标题、高亮、摘要、标签、实体和关系自动补齐。',
  },
  {
    from: 11.5,
    to: 16.5,
    kicker: '知识库',
    title: '按主题、来源和搜索回看',
    body: '每张卡保留来源，长期积累也能扫读。',
  },
  {
    from: 16.5,
    to: 21,
    kicker: '卡片详情',
    title: '每次保存都能复习和连接',
    body: '摘要、原文、来源、相关洞察都在一处。',
  },
  {
    from: 21,
    to: 25.8,
    kicker: '知识地图',
    title: '卡片点亮你的个人知识星图',
    body: '主题成为星座，实体和关系画出航线。',
  },
  {
    from: 25.8,
    to: 29,
    kicker: '知识罗盘',
    title: '下一步该探索什么，也能被提示',
    body: '已亮区域、模式、暗区和路线会被总结出来。',
  },
];

const Narration: React.FC<{current: number}> = ({current}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const item = narration.find((entry) => current >= entry.from && current < entry.to) ?? narration[narration.length - 1];
  const localFrame = frame - seconds(item.from, fps);
  const progress = spring({
    frame: localFrame,
    fps,
    durationInFrames: seconds(0.6, fps),
    config: {damping: 180},
  });
  const out = interpolate(
    frame,
    [seconds(item.to - 0.45, fps), seconds(item.to, fps)],
    [1, 0],
    clamp,
  );

  return (
    <div
      style={{
        position: 'absolute',
        left: 70,
        right: 70,
        top: 170,
        zIndex: 4,
        opacity: out,
        transform: `translateY(${interpolate(progress, [0, 1], [34, 0])}px)`,
      }}
    >
      <div style={{fontSize: 24, color: colors.teal, fontWeight: 860, marginBottom: 12}}>{item.kicker}</div>
      <div style={{fontSize: 54, lineHeight: 1.08, fontWeight: 930, maxWidth: 850, letterSpacing: 0}}>
        {item.title}
      </div>
      <div
        style={{
          fontSize: 27,
          lineHeight: 1.28,
          color: colors.sub,
          fontWeight: 650,
          maxWidth: 850,
          marginTop: 18,
        }}
      >
        {item.body}
      </div>
    </div>
  );
};

const FloatingSourcePanels: React.FC<{current: number}> = ({current}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const opacity = current < 7.4 ? 1 - fade(frame, fps, 6.8, 7.4) : 0;
  const panelY = slideY(frame, fps, 0.25, 0.9, 58);
  const highlightProgress = fade(frame, fps, 0.8, 1.8);
  const shareOpacity = fade(frame, fps, 2.1, 2.8) * (1 - fade(frame, fps, 3.5, 4.0));

  return (
    <div style={{position: 'absolute', inset: 0, opacity}}>
      <div
        style={{
          position: 'absolute',
          left: 88,
          top: 475 + panelY,
          width: 310,
          borderRadius: 26,
          background: 'rgba(255,255,255,0.82)',
          border: '1px solid rgba(17,24,39,0.08)',
          boxShadow: '0 22px 60px rgba(17,24,39,0.12)',
          padding: 18,
          transform: 'rotate(-2.5deg)',
        }}
      >
        <div style={{display: 'flex', gap: 9, marginBottom: 16}}>
          <Dot color="#ff5f57" />
          <Dot color="#febc2e" />
          <Dot color="#28c840" />
        </div>
        <div style={{fontSize: 17, color: colors.sub, fontWeight: 800, marginBottom: 10}}>Safari</div>
        <div style={{fontSize: 23, fontWeight: 850, lineHeight: 1.12}}>SwiftData migration notes</div>
        <div style={{height: 8}} />
        {['Keep lightweight migrations boring, test the shared container path, and ship with one obvious rollback story.', 'Share Extension reads the shared container.', 'Rollbacks should be obvious before launch.'].map(
          (line, index) => (
            <div
              key={line}
              style={{
                marginTop: 8,
                padding: index === 0 ? '7px 8px' : 0,
                borderRadius: 10,
                background: index === 0 ? `rgba(245,165,36,${0.18 * highlightProgress})` : 'transparent',
                fontSize: 15,
                lineHeight: 1.25,
                color: index === 0 ? colors.ink : colors.sub,
                fontWeight: index === 0 ? 760 : 560,
              }}
            >
              {line}
            </div>
          ),
        )}
      </div>
      <div
        style={{
          position: 'absolute',
          right: 78,
          top: 545,
          width: 292,
          borderRadius: 26,
          background: 'rgba(17,24,39,0.92)',
          color: '#fff',
          padding: 20,
          boxShadow: '0 24px 58px rgba(17,24,39,0.24)',
          transform: 'rotate(3deg)',
          opacity: fade(frame, fps, 1.2, 2.0),
        }}
      >
        <div style={{fontSize: 16, opacity: 0.62, fontWeight: 800, marginBottom: 12}}>ChatGPT</div>
        <div style={{fontSize: 21, lineHeight: 1.15, fontWeight: 840}}>AI reading workflow</div>
        <div style={{fontSize: 15, lineHeight: 1.32, opacity: 0.74, marginTop: 10}}>
          Capture first, organize second. Remove friction at the moment an idea appears.
        </div>
      </div>
      <ShareSheetPreview opacity={shareOpacity} />
    </div>
  );
};

const Dot: React.FC<{color: string}> = ({color}) => (
  <div style={{width: 10, height: 10, borderRadius: 99, background: color}} />
);

const ShareSheetPreview: React.FC<{opacity: number}> = ({opacity}) => (
  <div
    style={{
      position: 'absolute',
      left: 82,
      right: 82,
      bottom: 128,
      borderRadius: 38,
      padding: 24,
      background: 'rgba(255,255,255,0.9)',
      boxShadow: '0 30px 80px rgba(17,24,39,0.18)',
      border: '1px solid rgba(17,24,39,0.08)',
      opacity,
    }}
  >
    <div style={{fontSize: 22, fontWeight: 850, marginBottom: 18}}>Share</div>
    <div style={{display: 'flex', gap: 18}}>
      {['Messages', 'Notes', 'OmniSift', 'Copy'].map((name, index) => (
        <div key={name} style={{width: 132, textAlign: 'center'}}>
          <div
            style={{
              width: 78,
              height: 78,
              margin: '0 auto 10px',
              borderRadius: 24,
              background: name === 'OmniSift' ? '#0b0638' : ['#2f72ff', '#f5a524', '#98a2b3'][index] ?? colors.line,
              display: 'grid',
              placeItems: 'center',
              color: '#fff',
              fontSize: 28,
              fontWeight: 900,
              overflow: 'hidden',
            }}
          >
            {name === 'OmniSift' ? <Img src={staticFile('app-icon.png')} style={{width: 78, height: 78}} /> : name[0]}
          </div>
          <div style={{fontSize: 15, fontWeight: 650, color: colors.sub}}>{name}</div>
        </div>
      ))}
    </div>
  </div>
);

const PhoneFrame: React.FC<{screen: ScreenName; current: number}> = ({screen, current}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const intro = spring({
    frame: frame - seconds(0.25, fps),
    fps,
    durationInFrames: seconds(0.75, fps),
    config: {damping: 180},
  });
  const y = interpolate(intro, [0, 1], [82, 0]);
  const tilt = interpolate(frame, [0, seconds(30, fps)], [-1.3, 1.1], clamp);

  return (
    <div
      style={{
        position: 'absolute',
        left: 198,
        top: 430 + y,
        width: 684,
        height: 1180,
        borderRadius: 78,
        background: 'linear-gradient(145deg, #1f2937, #07111f)',
        padding: 17,
        boxShadow: '0 46px 120px rgba(17,24,39,0.28)',
        transform: `rotate(${tilt}deg)`,
        zIndex: 3,
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: '50%',
          top: 27,
          width: 148,
          height: 34,
          borderRadius: 999,
          background: '#030712',
          transform: 'translateX(-50%)',
          zIndex: 10,
        }}
      />
      <div
        style={{
          width: '100%',
          height: '100%',
          borderRadius: 62,
          overflow: 'hidden',
          background: '#f6f7f9',
          position: 'relative',
        }}
      >
        <PhoneStatusBar />
        <ScreenSwitcher screen={screen} current={current} />
      </div>
    </div>
  );
};

const PhoneStatusBar: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      left: 40,
      right: 40,
      top: 20,
      height: 28,
      zIndex: 20,
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      fontSize: 15,
      fontWeight: 800,
      color: colors.ink,
      opacity: 0.86,
    }}
  >
    <span>9:41</span>
    <span style={{fontSize: 13}}>●●●  5G  ▰</span>
  </div>
);

const ScreenSwitcher: React.FC<{screen: ScreenName; current: number}> = ({screen, current}) => {
  switch (screen) {
    case 'capture':
      return <CapturePhoneScreen current={current} />;
    case 'share':
      return <ShareExtensionScreen current={current} />;
    case 'processing':
      return <ProcessingScreen current={current} />;
    case 'library':
      return <LibraryScreen current={current} />;
    case 'detail':
      return <DetailScreen current={current} />;
    case 'map':
      return <KnowledgeMapScreen current={current} />;
    case 'compass':
      return <CompassScreen current={current} />;
    default:
      return <KnowledgeMapScreen current={current} />;
  }
};

const CapturePhoneScreen: React.FC<{current: number}> = ({current}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const scroll = interpolate(current, [0, 3.4], [0, -74], clamp);
  const highlight = fade(frame, fps, 0.7, 1.6);
  const selection = fade(frame, fps, 1.8, 2.6);
  return (
    <PhoneScreenBase background="#ffffff">
      <div style={{padding: '76px 30px 120px', transform: `translateY(${scroll}px)`}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 12, marginBottom: 22}}>
          <CircleIcon color={colors.blue} label="S" />
          <div>
            <div style={{fontSize: 19, fontWeight: 850}}>Safari</div>
            <div style={{fontSize: 13, color: colors.sub}}>developer.apple.com</div>
          </div>
        </div>
        <div style={{fontSize: 35, lineHeight: 1.08, fontWeight: 900}}>SwiftData migration notes</div>
        <div style={{fontSize: 16, color: colors.sub, marginTop: 12, lineHeight: 1.35}}>
          Notes for making shared stores safer between a main app and a Share Extension.
        </div>
        <ArticleLine width={520} top={34} />
        <ArticleLine width={470} />
        <div
          style={{
            marginTop: 18,
            padding: '10px 12px',
            borderRadius: 12,
            background: `rgba(245,165,36,${0.18 * highlight})`,
            color: colors.ink,
            fontSize: 18,
            lineHeight: 1.34,
            fontWeight: 720,
            outline: `2px solid rgba(245,165,36,${0.4 * highlight})`,
          }}
        >
          Keep lightweight migrations boring, test the shared container path, and ship with one obvious rollback story.
        </div>
        <ArticleLine width={510} top={18} />
        <ArticleLine width={390} />
        <div
          style={{
            marginTop: 32,
            borderRadius: 20,
            background: '#f2f4f7',
            padding: 18,
            display: 'flex',
            alignItems: 'center',
            gap: 16,
            opacity: selection,
          }}
        >
          <div style={{fontSize: 28}}>↗</div>
          <div>
            <div style={{fontSize: 18, fontWeight: 850}}>Share selected text</div>
            <div style={{fontSize: 14, color: colors.sub, marginTop: 3}}>Send to OmniSift</div>
          </div>
        </div>
      </div>
    </PhoneScreenBase>
  );
};

const ShareExtensionScreen: React.FC<{current: number}> = ({current}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const localFrame = local(frame, fps, 3.6);
  const panel = spring({frame: localFrame, fps, durationInFrames: seconds(0.75, fps), config: {damping: 170}});
  const savePulse = interpolate((localFrame + 18) % seconds(1.4, fps), [0, seconds(0.7, fps), seconds(1.4, fps)], [0, 1, 0]);
  return (
    <PhoneScreenBase background="#06111d">
      <ShareConstellationBackground />
      <div
        style={{
          position: 'absolute',
          left: 14,
          right: 14,
          bottom: 12 + interpolate(panel, [0, 1], [-420, 0]),
          borderRadius: 34,
          background: 'linear-gradient(145deg, rgba(5,18,31,0.98), rgba(5,44,48,0.98), rgba(34,25,14,0.96))',
          border: '1px solid rgba(255,255,255,0.16)',
          boxShadow: '0 -18px 48px rgba(0,0,0,0.36)',
          padding: '14px 22px 22px',
          color: '#fff',
        }}
      >
        <div style={{width: 42, height: 5, borderRadius: 999, background: 'rgba(255,255,255,0.22)', margin: '0 auto 16px'}} />
        <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
          <div
            style={{
              width: 46,
              height: 46,
              borderRadius: '50%',
              background: 'linear-gradient(135deg, #29c7b2, #f5b84b)',
              display: 'grid',
              placeItems: 'center',
              fontSize: 24,
            }}
          >
            ✦
          </div>
          <div style={{flex: 1}}>
            <div style={{fontSize: 23, fontWeight: 900}}>Save to OmniSift</div>
            <div style={{fontSize: 13, color: 'rgba(255,255,255,0.62)', marginTop: 3}}>AI will clean it later</div>
          </div>
          <div style={{fontSize: 18, opacity: 0.72}}>×</div>
        </div>
        <div
          style={{
            marginTop: 18,
            borderRadius: 22,
            background: 'rgba(255,255,255,0.08)',
            padding: 16,
            border: '1px solid rgba(255,255,255,0.08)',
          }}
        >
          <div style={{display: 'flex', justifyContent: 'space-between', marginBottom: 14}}>
            <div>
              <div style={{fontSize: 13, fontWeight: 800, opacity: 0.85}}>Incoming signal</div>
              <div style={{fontSize: 12, color: 'rgba(255,255,255,0.48)', marginTop: 2}}>Full article text captured</div>
            </div>
            <div
              style={{
                fontSize: 12,
                color: '#8fe7db',
                fontWeight: 850,
                padding: '6px 10px',
                borderRadius: 999,
                background: 'rgba(64,210,190,0.13)',
              }}
            >
              Full
            </div>
          </div>
          <div style={{fontSize: 17, fontWeight: 820, lineHeight: 1.2}}>SwiftData migration notes</div>
          <div style={{fontSize: 12, color: 'rgba(255,255,255,0.48)', marginTop: 8}}>developer.apple.com/documentation/swiftdata</div>
          <div style={{fontSize: 14, lineHeight: 1.34, color: 'rgba(255,255,255,0.72)', marginTop: 12}}>
            Keep lightweight migrations boring, test the shared container path, and ship with one obvious rollback story.
          </div>
        </div>
        <div style={{display: 'flex', justifyContent: 'space-between', marginTop: 14, fontSize: 13, color: 'rgba(255,255,255,0.62)'}}>
          <span>Free uses today</span>
          <span>4 / 5 left</span>
        </div>
        <div
          style={{
            marginTop: 16,
            height: 54,
            borderRadius: 18,
            background: `rgba(0,168,143,${0.94 + savePulse * 0.06})`,
            display: 'grid',
            placeItems: 'center',
            fontSize: 18,
            fontWeight: 900,
            boxShadow: `0 0 ${18 + savePulse * 18}px rgba(0,168,143,0.38)`,
          }}
        >
          Save to OmniSift
        </div>
      </div>
    </PhoneScreenBase>
  );
};

const ProcessingScreen: React.FC<{current: number}> = ({current}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const localFrame = local(frame, fps, 7.5);
  const progress = interpolate(localFrame, [0, seconds(3.2, fps)], [0, 1], clamp);
  const card = demoCards[1];
  return (
    <AppShell activeTab="cards" title="OmniSift">
      <div style={{padding: '10px 18px 108px'}}>
        <Segmented selected="Inbox" options={['Inbox', 'Library']} />
        <div style={{height: 14}} />
        <ProcessingCard progress={progress} />
        <div style={{height: 14}} />
        <CardRowMock card={card} index={1} compact opacity={fade(frame, fps, 9.3, 10.2)} />
      </div>
    </AppShell>
  );
};

const ProcessingCard: React.FC<{progress: number}> = ({progress}) => {
  const titleOpacity = interpolate(progress, [0.1, 0.35], [0, 1], clamp);
  const summaryOpacity = interpolate(progress, [0.35, 0.6], [0, 1], clamp);
  const tagsOpacity = interpolate(progress, [0.55, 0.8], [0, 1], clamp);
  return (
    <div
      style={{
        borderRadius: 18,
        background: 'rgba(255,255,255,0.86)',
        border: '1px solid rgba(17,24,39,0.08)',
        padding: 16,
        boxShadow: '0 14px 32px rgba(17,24,39,0.06)',
      }}
    >
      <div style={{display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12}}>
        <Badge color={colors.teal} text={progress < 0.85 ? 'Processing' : 'Done'} icon={progress < 0.85 ? '↻' : '✓'} />
        <Badge color={colors.green} text="Full" icon="▣" />
        <Badge color={colors.sub} text="Web" icon="◌" muted />
        <div style={{marginLeft: 'auto', fontSize: 12, color: colors.tertiary}}>Safari</div>
      </div>
      <SkeletonLabel label="Raw text" width={180} active={progress < 0.2} />
      <div style={{fontSize: 23, fontWeight: 880, lineHeight: 1.12, opacity: titleOpacity}}>
        SwiftData migration checklist
      </div>
      <div
        style={{
          marginTop: 12,
          paddingLeft: 10,
          borderLeft: `3px solid ${colors.teal}`,
          fontSize: 15,
          lineHeight: 1.26,
          color: colors.sub,
          fontStyle: 'italic',
          opacity: summaryOpacity,
        }}
      >
        Keep lightweight migrations boring, test the shared container path, and ship with one obvious rollback story.
      </div>
      <div style={{marginTop: 14, display: 'flex', flexWrap: 'wrap', gap: 7, opacity: tagsOpacity}}>
        {['iOS Architecture', 'Persistence', 'SwiftData', 'App Group'].map((tag) => (
          <Chip key={tag} text={tag} color={colors.teal} />
        ))}
      </div>
      <div style={{marginTop: 13, opacity: tagsOpacity}}>
        <MiniRelation text="SwiftData requires a stable migration plan" />
        <MiniRelation text="Share Extension reads the shared container" />
      </div>
    </div>
  );
};

const LibraryScreen: React.FC<{current: number}> = ({current}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const search = fade(frame, fps, 14.1, 15.1);
  const filtered = current >= 14.7;
  const shownCards = filtered ? [demoCards[0], demoCards[1]] : demoCards;
  return (
    <AppShell activeTab="cards" title="OmniSift">
      <div style={{padding: '8px 18px 108px'}}>
        <SearchBar text={filtered ? 'AI Research' : ''} opacity={search} />
        <div style={{height: 10}} />
        <Segmented selected="Library" options={['Inbox', 'Library']} />
        <div style={{marginTop: 12, display: 'flex', gap: 8, overflow: 'hidden'}}>
          {['All Topics', 'AI Research', 'iOS Architecture', 'OCR'].map((topic, index) => (
            <Chip key={topic} text={topic} color={index === (filtered ? 1 : 0) ? colors.teal : colors.sub} selected={index === (filtered ? 1 : 0)} />
          ))}
        </div>
        <div style={{height: 14}} />
        {shownCards.map((card, index) => (
          <CardRowMock key={card.title} card={card} index={index} opacity={1} compact={filtered && index > 0} />
        ))}
      </div>
    </AppShell>
  );
};

const DetailScreen: React.FC<{current: number}> = ({current}) => {
  const localTime = current - 16.5;
  const tab = localTime > 3.25 ? 'Source' : localTime > 2.55 ? 'Original' : 'Summary';
  const card = demoCards[0];
  return (
    <AppShell activeTab="cards" title="AI reading workflow" back>
      <div style={{padding: '72px 20px 108px'}}>
        <div style={{display: 'flex', gap: 8, alignItems: 'center'}}>
          <Badge color={colors.green} text="Done" icon="✓" />
          <Badge color={colors.sub} text="Text" icon="T" muted />
          <Badge color={colors.sub} text="Text" icon="◌" muted />
          <div style={{marginLeft: 'auto', fontSize: 12, color: colors.sub}}>ChatGPT</div>
        </div>
        <div style={{fontSize: 28, lineHeight: 1.08, fontWeight: 900, marginTop: 14}}>{card.title}</div>
        <div style={{height: 16}} />
        <Segmented selected={tab} options={['Summary', 'Original', 'Source']} />
        <div style={{height: 18}} />
        {tab === 'Summary' && <SummaryDetail card={card} />}
        {tab === 'Original' && <OriginalDetail />}
        {tab === 'Source' && <SourceDetail card={card} />}
      </div>
    </AppShell>
  );
};

const SummaryDetail: React.FC<{card: DemoCard}> = ({card}) => (
  <div>
    <QuoteBlock text={card.highlight} />
    <SectionTitle icon="☰" title="Summary" />
    <div style={{fontSize: 16, lineHeight: 1.38, color: colors.ink, marginTop: 8}}>{card.summary}</div>
    <SectionTitle icon="▦" title="Knowledge" top={20} />
    <LabelGroup title="Topics" labels={card.topics} color={colors.teal} />
    <LabelGroup title="Tags" labels={card.keywords} color={colors.blue} />
    <LabelGroup title="Entities" labels={card.entities} color={colors.purple} />
    <div style={{marginTop: 14}}>
      <div style={{fontSize: 12, color: colors.sub, fontWeight: 850, marginBottom: 7}}>Relations</div>
      {card.relations.map((relation) => (
        <MiniRelation key={relation} text={relation} />
      ))}
    </div>
    <SectionTitle icon="△" title="Related Insights" top={18} />
    <RelatedCard title="SwiftData migration checklist" reason="Shared: Knowledge Graph, capture" />
  </div>
);

const OriginalDetail: React.FC = () => (
  <div>
    <SectionTitle icon="□" title="Original Content" />
    <div
      style={{
        borderRadius: 16,
        background: 'rgba(255,255,255,0.88)',
        border: '1px solid rgba(17,24,39,0.08)',
        padding: 16,
        fontSize: 15,
        lineHeight: 1.4,
        color: colors.ink,
      }}
    >
      <b>Research workflow conversation</b>
      <br />
      <br />
      Capture first, organize second. The key is removing friction at the moment an idea appears.
      Saved paragraphs should become searchable cards with summaries, tags, entities, and related concepts.
    </div>
    <div style={{display: 'flex', justifyContent: 'space-between', color: colors.tertiary, fontSize: 12, marginTop: 12}}>
      <span>Text</span>
      <span>286 chars</span>
    </div>
  </div>
);

const SourceDetail: React.FC<{card: DemoCard}> = ({card}) => (
  <div>
    <SectionTitle icon="↗" title="Source" />
    <div
      style={{
        borderRadius: 16,
        background: 'rgba(255,255,255,0.88)',
        border: '1px solid rgba(17,24,39,0.08)',
        padding: 16,
      }}
    >
      <div style={{fontSize: 18, fontWeight: 850}}>{card.sourceTitle}</div>
      <div style={{fontSize: 13, color: colors.sub, marginTop: 8}}>Captured from {card.sourceApp}</div>
      <div style={{height: 12}} />
      <div
        style={{
          borderRadius: 14,
          height: 46,
          background: colors.teal,
          color: '#fff',
          display: 'grid',
          placeItems: 'center',
          fontSize: 16,
          fontWeight: 860,
        }}
      >
        Open in {card.sourceApp}
      </div>
    </div>
    <div style={{marginTop: 16, fontSize: 12, color: colors.tertiary}}>AI 88% · Just now</div>
  </div>
);

const KnowledgeMapScreen: React.FC<{current: number}> = ({current}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const localFrame = local(frame, fps, 21);
  return (
    <AppShell activeTab="map" title="">
        <div style={{padding: '112px 18px 108px'}}>
        <div style={{fontSize: 32, fontWeight: 930}}>Knowledge Map</div>
        <div style={{fontSize: 14, color: colors.sub, lineHeight: 1.3, marginTop: 7}}>
          Collecting lights the map; the compass reads it and points to the next route.
        </div>
        <TopicOrganizationEntry />
        <GalaxyPanel localFrame={localFrame} />
      </div>
    </AppShell>
  );
};

const CompassScreen: React.FC<{current: number}> = ({current}) => {
  const localTime = current - 25.8;
  const selected = localTime > 2.2 ? 'Route' : localTime > 1.45 ? 'Dark' : localTime > 0.75 ? 'Pattern' : 'Lit';
  return (
    <AppShell activeTab="map" title="">
      <div style={{padding: '112px 18px 108px'}}>
        <div style={{fontSize: 32, fontWeight: 930}}>Knowledge Map</div>
        <CompassPanel selected={selected} immersive />
      </div>
    </AppShell>
  );
};

const FinalCard: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      background: 'linear-gradient(180deg, rgba(255,250,242,0.78), #fffaf2)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      textAlign: 'center',
      zIndex: 40,
    }}
  >
    <div>
      <Img
        src={staticFile('app-icon.png')}
        style={{
          width: 188,
          height: 188,
          borderRadius: 48,
          boxShadow: '0 34px 78px rgba(17,24,39,0.22)',
        }}
      />
      <div style={{fontSize: 74, fontWeight: 950, marginTop: 40}}>OmniSift</div>
      <div style={{fontSize: 30, color: colors.sub, marginTop: 6}}>知漏</div>
      <div style={{fontSize: 39, lineHeight: 1.12, fontWeight: 880, width: 760, marginTop: 34}}>
        Capture ideas. Light your map.
      </div>
      <div
        style={{
          margin: '56px auto 0',
          width: 420,
          height: 68,
          borderRadius: 26,
          background: colors.ink,
          color: '#fff',
          display: 'grid',
          placeItems: 'center',
          fontSize: 25,
          fontWeight: 850,
          boxShadow: '0 20px 48px rgba(17,24,39,0.22)',
        }}
      >
        Download on the App Store
      </div>
    </div>
  </div>
);

const PhoneScreenBase: React.FC<{children: React.ReactNode; background: string}> = ({children, background}) => (
  <div style={{position: 'absolute', inset: 0, background, overflow: 'hidden'}}>{children}</div>
);

const AppShell: React.FC<{
  children: React.ReactNode;
  activeTab: 'map' | 'cards' | 'settings';
  title: string;
  back?: boolean;
}> = ({children, activeTab, title, back}) => (
  <PhoneScreenBase background="#f5f6f8">
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        top: 0,
        height: 98,
        background: 'rgba(245,246,248,0.92)',
        borderBottom: '1px solid rgba(17,24,39,0.06)',
        zIndex: 15,
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: 26,
          right: 26,
          bottom: 14,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
        }}
      >
        <div style={{fontSize: 18, color: colors.teal, fontWeight: 850}}>{back ? '‹ Back' : ''}</div>
        <div style={{fontSize: 18, fontWeight: 850}}>{title}</div>
        <div style={{fontSize: 24, color: colors.ink}}>•••</div>
      </div>
    </div>
    <div style={{position: 'absolute', inset: 0, overflow: 'hidden'}}>{children}</div>
    <TabBar activeTab={activeTab} />
  </PhoneScreenBase>
);

const TabBar: React.FC<{activeTab: 'map' | 'cards' | 'settings'}> = ({activeTab}) => (
  <div
    style={{
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      height: 94,
      background: 'rgba(255,255,255,0.94)',
      borderTop: '1px solid rgba(17,24,39,0.08)',
      display: 'flex',
      justifyContent: 'space-around',
      alignItems: 'flex-start',
      paddingTop: 12,
      zIndex: 20,
    }}
  >
    <TabItem icon="△" label="Map" active={activeTab === 'map'} />
    <TabItem icon="▣" label="Library" active={activeTab === 'cards'} />
    <TabItem icon="⚙" label="Settings" active={activeTab === 'settings'} />
  </div>
);

const TabItem: React.FC<{icon: string; label: string; active: boolean}> = ({icon, label, active}) => (
  <div style={{textAlign: 'center', color: active ? colors.teal : colors.tertiary, width: 132}}>
    <div style={{fontSize: 23, lineHeight: 1}}>{icon}</div>
    <div style={{fontSize: 12, fontWeight: active ? 850 : 650, marginTop: 5}}>{label}</div>
  </div>
);

const CardRowMock: React.FC<{card: DemoCard; index: number; opacity: number; compact?: boolean}> = ({
  card,
  index,
  opacity,
  compact,
}) => (
  <div
    style={{
      borderRadius: 18,
      background: 'rgba(255,255,255,0.86)',
      border: '1px solid rgba(17,24,39,0.08)',
      padding: 15,
      marginBottom: 13,
      boxShadow: '0 12px 28px rgba(17,24,39,0.055)',
      opacity,
      transform: `translateY(${opacity < 1 ? 24 : 0}px)`,
    }}
  >
    <div style={{display: 'flex', alignItems: 'center', gap: 7, marginBottom: 10}}>
      <Badge color={colors.green} text="Done" icon="✓" />
      <Badge color={card.extraction === 'Full' ? colors.green : colors.sub} text={card.extraction} icon="▣" muted={card.extraction !== 'Full'} />
      <Badge color={colors.sub} text={card.method} icon="◌" muted />
      <div style={{marginLeft: 'auto', fontSize: 12, color: colors.sub}}>{card.sourceApp}</div>
      <div style={{fontSize: 11, color: colors.tertiary}}>{card.age}</div>
    </div>
    <div style={{fontSize: compact ? 19 : 21, fontWeight: 880, lineHeight: 1.12}}>{card.title}</div>
    {!compact && (
      <div
        style={{
          marginTop: 10,
          paddingLeft: 10,
          borderLeft: `3px solid ${card.accent}`,
          fontSize: 14,
          lineHeight: 1.28,
          color: colors.sub,
          fontStyle: 'italic',
        }}
      >
        {card.highlight}
      </div>
    )}
    {card.sourceURL && !compact && (
      <div style={{fontSize: 11, color: colors.tertiary, marginTop: 10}}>↗ {card.sourceURL}</div>
    )}
    <div style={{display: 'flex', gap: 6, marginTop: 12, flexWrap: 'wrap'}}>
      {card.topics.slice(0, compact ? 2 : 3).map((tag) => (
        <Chip key={tag} text={tag} color={card.accent} />
      ))}
    </div>
  </div>
);

const Badge: React.FC<{color: string; text: string; icon: string; muted?: boolean}> = ({color, text, icon, muted}) => (
  <div style={{display: 'flex', gap: 4, alignItems: 'center', fontSize: 11, fontWeight: 820, color: muted ? colors.sub : color}}>
    <span>{icon}</span>
    <span>{text}</span>
  </div>
);

const Chip: React.FC<{text: string; color: string; selected?: boolean}> = ({text, color, selected}) => (
  <div
    style={{
      fontSize: 11,
      fontWeight: 760,
      color: selected ? color : colors.sub,
      padding: '5px 9px',
      borderRadius: 999,
      background: selected ? `${color}25` : 'rgba(17,24,39,0.06)',
      whiteSpace: 'nowrap',
    }}
  >
    {text}
  </div>
);

const Segmented: React.FC<{selected: string; options: string[]}> = ({selected, options}) => (
  <div
    style={{
      height: 38,
      borderRadius: 12,
      background: 'rgba(17,24,39,0.07)',
      padding: 3,
      display: 'flex',
      gap: 3,
    }}
  >
    {options.map((option) => (
      <div
        key={option}
        style={{
          flex: 1,
          borderRadius: 10,
          background: selected === option ? '#fff' : 'transparent',
          display: 'grid',
          placeItems: 'center',
          fontSize: 13,
          fontWeight: 840,
          color: selected === option ? colors.ink : colors.sub,
          boxShadow: selected === option ? '0 2px 6px rgba(17,24,39,0.10)' : 'none',
        }}
      >
        {option}
      </div>
    ))}
  </div>
);

const SearchBar: React.FC<{text: string; opacity: number}> = ({text, opacity}) => (
  <div
    style={{
      height: 42,
      borderRadius: 16,
      background: 'rgba(255,255,255,0.86)',
      border: '1px solid rgba(17,24,39,0.08)',
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '0 14px',
      fontSize: 14,
      color: text ? colors.ink : colors.tertiary,
    }}
  >
    <span>⌕</span>
    <span style={{opacity: text ? opacity : 1}}>{text || 'Search insights, topics, sources'}</span>
  </div>
);

const SectionTitle: React.FC<{icon: string; title: string; top?: number}> = ({icon, title, top = 0}) => (
  <div style={{display: 'flex', alignItems: 'center', gap: 8, marginTop: top, color: colors.sub, fontSize: 13, fontWeight: 850}}>
    <span>{icon}</span>
    <span>{title}</span>
  </div>
);

const QuoteBlock: React.FC<{text: string}> = ({text}) => (
  <div
    style={{
      borderRadius: 14,
      background: 'rgba(0,168,143,0.08)',
      borderLeft: `4px solid ${colors.teal}`,
      padding: 14,
      fontSize: 16,
      lineHeight: 1.34,
      fontStyle: 'italic',
      color: colors.ink,
    }}
  >
    {text}
  </div>
);

const LabelGroup: React.FC<{title: string; labels: string[]; color: string}> = ({title, labels, color}) => (
  <div style={{marginTop: 12}}>
    <div style={{fontSize: 12, color: colors.sub, fontWeight: 850, marginBottom: 7}}>{title}</div>
    <div style={{display: 'flex', flexWrap: 'wrap', gap: 7}}>
      {labels.map((label) => (
        <Chip key={label} text={label} color={color} selected />
      ))}
    </div>
  </div>
);

const MiniRelation: React.FC<{text: string}> = ({text}) => (
  <div style={{fontSize: 12, color: colors.sub, lineHeight: 1.25, marginTop: 5}}>• {text}</div>
);

const RelatedCard: React.FC<{title: string; reason: string}> = ({title, reason}) => (
  <div
    style={{
      borderRadius: 14,
      background: 'rgba(255,255,255,0.9)',
      border: '1px solid rgba(17,24,39,0.08)',
      padding: 12,
    }}
  >
    <div style={{fontSize: 15, fontWeight: 850}}>{title}</div>
    <div style={{fontSize: 12, color: colors.sub, marginTop: 5}}>{reason}</div>
  </div>
);

const TopicOrganizationEntry: React.FC = () => (
  <div
    style={{
      marginTop: 16,
      borderRadius: 20,
      background: 'rgba(255,255,255,0.88)',
      border: '1px solid rgba(245,165,36,0.18)',
      padding: 14,
      display: 'flex',
      alignItems: 'center',
      gap: 13,
    }}
  >
    <div
      style={{
        width: 44,
        height: 44,
        borderRadius: 14,
        background: `linear-gradient(135deg, ${colors.orange}, ${colors.teal})`,
        color: '#fff',
        display: 'grid',
        placeItems: 'center',
        fontSize: 22,
      }}
    >
      ▦
    </div>
    <div style={{flex: 1}}>
      <div style={{fontSize: 16, fontWeight: 850}}>Organize Topics</div>
      <div style={{fontSize: 12, color: colors.sub, marginTop: 3}}>Review overview, signals, and AI star-map organization.</div>
    </div>
    <div style={{color: colors.tertiary}}>›</div>
  </div>
);

const GalaxyPanel: React.FC<{localFrame: number}> = ({localFrame}) => {
  const {fps} = useVideoConfig();
  const glow = interpolate((localFrame + 12) % seconds(1.6, fps), [0, seconds(0.8, fps), seconds(1.6, fps)], [0, 1, 0]);
  return (
    <div
      style={{
        marginTop: 16,
        borderRadius: 26,
        background: 'linear-gradient(140deg, rgba(7,18,32,0.96), rgba(11,75,77,0.74), rgba(90,57,14,0.42))',
        color: '#fff',
        border: '1px solid rgba(255,255,255,0.12)',
        padding: 17,
      }}
    >
      <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start'}}>
        <div>
          <div style={{fontSize: 23, fontWeight: 900}}>Knowledge Galaxy</div>
          <div style={{fontSize: 12, lineHeight: 1.28, color: 'rgba(255,255,255,0.66)', marginTop: 5, width: 430}}>
            Every saved card lights a star. Themes become constellations.
          </div>
        </div>
        <div style={{fontSize: 22, color: '#f8c45a'}}>✦</div>
      </div>
      <div style={{display: 'flex', gap: 7, marginTop: 12}}>
        <Metric value="4" label="Constellations" color={colors.orange} />
        <Metric value="4" label="Stars" color="#fdd66b" />
        <Metric value="9" label="Entities" color="#62d6c8" />
        <Metric value="6" label="Links" color="#7ca7ff" />
      </div>
      <div
        style={{
          position: 'relative',
          marginTop: 14,
          height: 330,
          borderRadius: 22,
          overflow: 'hidden',
          background: 'linear-gradient(145deg, #020712, #082234, #07333a)',
        }}
      >
        <StarDust />
        <GalaxyLines />
        {[
          {x: 310, y: 82, name: 'AI Research', color: colors.teal, stars: 4},
          {x: 160, y: 194, name: 'iOS Architecture', color: colors.blue, stars: 3},
          {x: 410, y: 205, name: 'Capture Methods', color: colors.coral, stars: 3},
          {x: 292, y: 270, name: 'Product Strategy', color: colors.orange, stars: 2},
        ].map((node, index) => (
          <Constellation key={node.name} node={node} delay={index * 0.16} localFrame={localFrame} glow={glow} />
        ))}
      </div>
      <div style={{display: 'flex', alignItems: 'center', marginTop: 13, gap: 8}}>
        <span style={{color: '#f8c45a'}}>✦</span>
        <span style={{fontSize: 12, color: 'rgba(255,255,255,0.78)', flex: 1}}>
          More processed cards light more stars inside each constellation.
        </span>
        <span
          style={{
            fontSize: 11,
            fontWeight: 850,
            color: '#f8c45a',
            padding: '5px 8px',
            borderRadius: 999,
            background: 'rgba(248,196,90,0.16)',
          }}
        >
          4 lit
        </span>
      </div>
    </div>
  );
};

const Metric: React.FC<{value: string; label: string; color: string}> = ({value, label, color}) => (
  <div
    style={{
      borderRadius: 999,
      background: 'rgba(255,255,255,0.10)',
      padding: '7px 9px',
      display: 'flex',
      alignItems: 'baseline',
      gap: 4,
      whiteSpace: 'nowrap',
    }}
  >
    <span style={{fontSize: 15, color, fontWeight: 900}}>{value}</span>
    <span style={{fontSize: 10, color: 'rgba(255,255,255,0.72)', fontWeight: 760}}>{label}</span>
  </div>
);

const StarDust: React.FC = () => (
  <>
    {Array.from({length: 54}).map((_, index) => (
      <div
        key={index}
        style={{
          position: 'absolute',
          left: ((index * 37 + 19) % 100) + '%',
          top: ((index * 61 + 11) % 100) + '%',
          width: index % 9 === 0 ? 3 : 2,
          height: index % 9 === 0 ? 3 : 2,
          borderRadius: 99,
          background: `rgba(255,255,255,${index % 4 === 0 ? 0.42 : 0.20})`,
        }}
      />
    ))}
  </>
);

const GalaxyLines: React.FC = () => (
  <svg width="100%" height="100%" viewBox="0 0 520 330" style={{position: 'absolute', inset: 0}}>
    <path d="M40 116 C150 36 328 42 500 102" stroke="rgba(255,255,255,0.07)" strokeWidth="1.4" fill="none" strokeDasharray="6 13" />
    <path d="M28 220 C180 292 360 142 508 210" stroke="rgba(255,255,255,0.08)" strokeWidth="1.2" fill="none" strokeDasharray="5 12" />
    <line x1="310" y1="82" x2="160" y2="194" stroke="rgba(255,255,255,0.14)" />
    <line x1="310" y1="82" x2="410" y2="205" stroke="rgba(255,255,255,0.14)" />
    <line x1="160" y1="194" x2="292" y2="270" stroke="rgba(255,255,255,0.10)" />
    <line x1="410" y1="205" x2="292" y2="270" stroke="rgba(255,255,255,0.10)" />
  </svg>
);

const Constellation: React.FC<{
  node: {x: number; y: number; name: string; color: string; stars: number};
  delay: number;
  localFrame: number;
  glow: number;
}> = ({node, delay, localFrame, glow}) => {
  const {fps} = useVideoConfig();
  const p = spring({
    frame: localFrame - seconds(delay, fps),
    fps,
    durationInFrames: seconds(0.8, fps),
    config: {damping: 150},
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: node.x,
        top: node.y,
        transform: `translate(-50%, -50%) scale(${interpolate(p, [0, 1], [0.72, 1])})`,
        opacity: interpolate(p, [0, 0.2, 1], [0, 1, 1], clamp),
      }}
    >
      <div
        style={{
          width: 104,
          height: 72,
          borderRadius: 28,
          background: `${node.color}18`,
          border: `1px solid ${node.color}55`,
          boxShadow: `0 0 ${18 + glow * 18}px ${node.color}55`,
          position: 'relative',
        }}
      >
        {Array.from({length: node.stars}).map((_, index) => (
          <div
            key={index}
            style={{
              position: 'absolute',
              left: [18, 42, 66, 80][index],
              top: [24, 14, 34, 20][index],
              width: 7,
              height: 7,
              borderRadius: 99,
              background: node.color,
              boxShadow: `0 0 12px ${node.color}`,
            }}
          />
        ))}
      </div>
      <div style={{fontSize: 10, textAlign: 'center', marginTop: 5, color: 'rgba(255,255,255,0.82)', fontWeight: 800}}>
        {node.name}
      </div>
    </div>
  );
};

const CompassPanel: React.FC<{selected: string; immersive?: boolean}> = ({selected}) => {
  const directions = [
    {name: 'Lit', color: colors.blue, icon: '⌖', text: 'AI Research and Knowledge Capture are your brightest constellations.'},
    {name: 'Pattern', color: '#18bcd0', icon: '✦', text: 'Most saved ideas are about reducing friction before organization.'},
    {name: 'Dark', color: colors.orange, icon: '?', text: 'You have fewer counterexamples and long-term review notes.'},
    {name: 'Route', color: colors.green, icon: '↗', text: 'Search: "capture workflows with spaced review" and save two comparisons.'},
  ];
  const active = directions.find((direction) => direction.name === selected) ?? directions[0];
  return (
    <div
      style={{
        marginTop: 20,
        borderRadius: 26,
        background: `linear-gradient(140deg, ${active.color}22, rgba(255,255,255,0.94), rgba(245,165,36,0.10))`,
        border: `1px solid ${active.color}44`,
        padding: 18,
        boxShadow: `0 18px 44px ${active.color}22`,
      }}
    >
      <div style={{display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between'}}>
        <div style={{maxWidth: 405}}>
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
              fontSize: 12,
              color: active.color,
              fontWeight: 850,
              padding: '6px 10px',
              borderRadius: 999,
              background: `${active.color}18`,
              marginBottom: 10,
            }}
          >
            {active.icon} Compass Bearing
          </div>
          <div style={{fontSize: 22, lineHeight: 1.18, fontWeight: 900}}>
            Your map says: capture is strong, review routes need more evidence.
          </div>
        </div>
        <div
          style={{
            width: 50,
            height: 50,
            borderRadius: '50%',
            background: `${active.color}20`,
            color: active.color,
            display: 'grid',
            placeItems: 'center',
            fontSize: 22,
            fontWeight: 900,
          }}
        >
          ↻
        </div>
      </div>
      <div style={{fontSize: 12, color: colors.sub, lineHeight: 1.3, marginTop: 14}}>
        Turn the compass to read lit areas, patterns, dark zones, and routes.
      </div>
      <CompassDial directions={directions} selected={selected} />
      <div
        style={{
          borderRadius: 18,
          background: 'rgba(255,255,255,0.84)',
          border: '1px solid rgba(17,24,39,0.08)',
          padding: 15,
          marginTop: 16,
        }}
      >
        <div style={{fontSize: 13, color: active.color, fontWeight: 880, marginBottom: 8}}>{selected}</div>
        <div style={{fontSize: 17, lineHeight: 1.32, color: colors.ink, fontWeight: 720}}>{active.text}</div>
      </div>
    </div>
  );
};

const CompassDial: React.FC<{directions: Array<{name: string; color: string; icon: string}>; selected: string}> = ({
  directions,
  selected,
}) => (
  <div
    style={{
      margin: '16px auto 0',
      width: 286,
      height: 286,
      borderRadius: '50%',
      position: 'relative',
      background: 'radial-gradient(circle, rgba(255,255,255,0.95) 0 34%, rgba(17,24,39,0.06) 35% 36%, rgba(255,255,255,0.5) 37% 100%)',
      border: '1px solid rgba(17,24,39,0.08)',
    }}
  >
    {directions.map((direction, index) => {
      const angle = -90 + index * 90;
      const active = selected === direction.name;
      const x = 143 + Math.cos((angle * Math.PI) / 180) * 98;
      const y = 143 + Math.sin((angle * Math.PI) / 180) * 98;
      return (
        <div
          key={direction.name}
          style={{
            position: 'absolute',
            left: x,
            top: y,
            width: 70,
            height: 54,
            transform: 'translate(-50%, -50%)',
            borderRadius: 18,
            background: active ? direction.color : 'rgba(255,255,255,0.82)',
            color: active ? '#fff' : direction.color,
            display: 'grid',
            placeItems: 'center',
            fontSize: 12,
            fontWeight: 880,
            boxShadow: active ? `0 12px 28px ${direction.color}44` : 'none',
          }}
        >
          <div>{direction.icon}</div>
          <div>{direction.name}</div>
        </div>
      );
    })}
    <div
      style={{
        position: 'absolute',
        left: '50%',
        top: '50%',
        width: 18,
        height: 110,
        borderRadius: 999,
        background: directions.find((direction) => direction.name === selected)?.color,
        transformOrigin: '50% 88%',
        transform: `translate(-50%, -88%) rotate(${['Lit', 'Pattern', 'Dark', 'Route'].indexOf(selected) * 90}deg)`,
      }}
    />
    <div
      style={{
        position: 'absolute',
        left: '50%',
        top: '50%',
        width: 54,
        height: 54,
        borderRadius: '50%',
        background: colors.ink,
        transform: 'translate(-50%, -50%)',
      }}
    />
  </div>
);

const CircleIcon: React.FC<{color: string; label: string}> = ({color, label}) => (
  <div
    style={{
      width: 42,
      height: 42,
      borderRadius: 14,
      background: color,
      color: '#fff',
      display: 'grid',
      placeItems: 'center',
      fontSize: 18,
      fontWeight: 900,
    }}
  >
    {label}
  </div>
);

const ArticleLine: React.FC<{width: number; top?: number}> = ({width, top = 10}) => (
  <div style={{width, height: 10, borderRadius: 999, background: '#e4e7ec', marginTop: top}} />
);

const SkeletonLabel: React.FC<{label: string; width: number; active: boolean}> = ({label, width, active}) => (
  <div style={{display: active ? 'block' : 'none', marginBottom: 10}}>
    <div style={{fontSize: 12, color: colors.tertiary, fontWeight: 800, marginBottom: 7}}>{label}</div>
    <ArticleLine width={width} top={0} />
    <ArticleLine width={width + 130} />
  </div>
);

const ShareConstellationBackground: React.FC = () => (
  <>
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background:
          'radial-gradient(circle at 22% 18%, rgba(41,199,178,0.22), transparent 30%), radial-gradient(circle at 80% 50%, rgba(245,184,75,0.16), transparent 28%), #06111d',
      }}
    />
    {Array.from({length: 42}).map((_, index) => (
      <div
        key={index}
        style={{
          position: 'absolute',
          left: ((index * 29 + 13) % 100) + '%',
          top: ((index * 47 + 9) % 100) + '%',
          width: index % 8 === 0 ? 4 : 2,
          height: index % 8 === 0 ? 4 : 2,
          borderRadius: 99,
          background: `rgba(255,255,255,${index % 4 === 0 ? 0.38 : 0.18})`,
        }}
      />
    ))}
  </>
);
