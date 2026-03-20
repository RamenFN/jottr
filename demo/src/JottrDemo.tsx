import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
  Easing,
} from 'remotion';

// ─── Brand ───────────────────────────────────────────────────────────────────
const C = {
  bg: '#111113',
  surface: '#1C1C1E',
  card: '#232325',
  border: 'rgba(255,255,255,0.07)',
  amber: '#F97316',
  amberDim: 'rgba(249,115,22,0.15)',
  white: '#F5F5F0',
  muted: 'rgba(245,245,240,0.38)',
  menuBar: '#161618',
};
const FONT = "system-ui,-apple-system,'SF Pro Display','Helvetica Neue',sans-serif";

// ─── Timing (frames @ 30fps = 14s) ────────────────────────────────────────
const T = {
  // Scene 1 – mac screen slides in
  SCREEN_IN: 0,
  EDITOR_IN: 12,
  CURSOR_START: 40,

  // Scene 2 – notch drops
  NOTCH_DROP: 68,
  WAVEFORM_START: 82,

  // Scene 3 – raw words type in
  WORDS_START: 90,
  WORDS_END: 185,

  // Scene 4 – key release, notch exits
  NOTCH_EXIT: 188,
  TRANSCRIBING_IN: 196,
  TRANSCRIBING_OUT: 230,

  // Scene 5 – shimmer sweep
  SHIMMER_START: 228,
  SHIMMER_END: 268,

  // Scene 6 – clean result payoff
  CLEAN_WORDS_START: 262,
  UNDERLINE_IN: 292,

  TOTAL: 420,
};

const RAW_WORDS = ['um', 'so', 'basically', 'uh', 'the', 'meeting', 'went', 'really', 'well', 'you', 'know', 'like'];
const CLEAN_WORDS = ['The', 'meeting', 'went', 'well.'];

// ─── Helpers ─────────────────────────────────────────────────────────────────
function easedSpring(frame: number, fps: number, delay = 0, stiffness = 160, damping = 18) {
  return spring({ frame: Math.max(0, frame - delay), fps, config: { stiffness, damping } });
}

function fadeSlideUp(frame: number, from: number, duration = 16, distance = 18): { opacity: number; ty: number } {
  const local = frame - from;
  const opacity = interpolate(local, [0, duration * 0.7], [0, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  const ty = interpolate(local, [0, duration], [distance, 0], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.out(Easing.back(1.4)),
  });
  return { opacity, ty };
}

// ─── Notch Overlay (faithful recreation of the real app UI) ──────────────────
const NotchOverlay: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const localIn = frame - T.NOTCH_DROP;
  const localOut = frame - T.NOTCH_EXIT;

  // Drop in with spring overshoot
  const dropIn = spring({ frame: Math.max(0, localIn), fps, config: { stiffness: 220, damping: 14 } });
  // Slide out fast (ease in)
  const slideOut = frame >= T.NOTCH_EXIT
    ? interpolate(localOut, [0, 14], [0, 1], { extrapolateRight: 'clamp', easing: Easing.in(Easing.cubic) })
    : 0;

  const visible = frame >= T.NOTCH_DROP && frame < T.NOTCH_EXIT + 16;
  if (!visible) return null;

  const translateY = interpolate(dropIn, [0, 1], [-52, 0]) * (1 - slideOut);
  const opacity = interpolate(dropIn, [0, 0.3], [0, 1], { extrapolateRight: 'clamp' }) * (1 - slideOut);

  const waveLocal = frame - T.WAVEFORM_START;
  const BASE_H = [18, 28, 38, 30, 44, 32, 26, 36, 20];
  const pulseOpacity = 0.6 + 0.4 * Math.sin(frame * 0.15);

  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: '50%',
        transform: `translateX(-50%) translateY(${translateY}px)`,
        opacity,
        zIndex: 100,
        width: 230,
        height: 34,
        background: 'black',
        borderRadius: '0 0 20px 20px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 6,
        paddingLeft: 12,
        paddingRight: 10,
        boxSizing: 'border-box',
        boxShadow: '0 4px 24px rgba(0,0,0,0.6)',
      }}
    >
      {/* Pulsing amber record dot */}
      <div style={{
        width: 6, height: 6, borderRadius: '50%',
        background: C.amber,
        opacity: pulseOpacity,
        flexShrink: 0,
        boxShadow: `0 0 6px ${C.amber}`,
      }} />

      {/* Waveform bars */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 2.5, flex: 1, justifyContent: 'center' }}>
        {BASE_H.map((bh, i) => {
          const phase = (waveLocal / 7 + i * 0.65) * Math.PI;
          const wave = Math.sin(phase) * 0.45 + Math.sin(phase * 1.8 + i) * 0.25;
          const h = Math.max(4, Math.min(40, bh + wave * 14));
          return (
            <div key={i} style={{
              width: 3, height: h, borderRadius: 2,
              background: C.amber,
              boxShadow: `0 0 4px rgba(249,115,22,0.4)`,
            }} />
          );
        })}
      </div>

      {/* Intensity badge */}
      <div style={{
        fontSize: 9, fontWeight: 800, color: '#fff', fontFamily: FONT,
        background: C.amber, borderRadius: 4,
        padding: '1.5px 5px',
        letterSpacing: '0.02em',
        flexShrink: 0,
      }}>
        L2
      </div>
    </div>
  );
};

// ─── Transcribing dots (3 amber dots) ────────────────────────────────────────
const TranscribingDots: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const localIn = frame - T.TRANSCRIBING_IN;
  const localOut = frame - T.TRANSCRIBING_OUT;
  const visible = frame >= T.TRANSCRIBING_IN && frame < T.TRANSCRIBING_OUT + 12;
  if (!visible) return null;

  const inSpring = spring({ frame: Math.max(0, localIn), fps, config: { stiffness: 200, damping: 16 } });
  const outOpacity = frame >= T.TRANSCRIBING_OUT
    ? interpolate(localOut, [0, 12], [1, 0], { extrapolateRight: 'clamp' })
    : 1;

  const translateY = interpolate(inSpring, [0, 1], [-44, 0]);
  const opacity = interpolate(inSpring, [0, 0.4], [0, 1], { extrapolateRight: 'clamp' }) * outOpacity;

  return (
    <div style={{
      position: 'absolute', top: 0, left: '50%',
      transform: `translateX(-50%) translateY(${translateY}px)`,
      opacity,
      zIndex: 100,
      width: 56, height: 28,
      background: 'black',
      borderRadius: '0 0 14px 14px',
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5,
      boxShadow: '0 4px 20px rgba(0,0,0,0.5)',
    }}>
      {[0, 1, 2].map(i => {
        const dotPulse = 0.3 + 0.7 * ((Math.sin((frame * 0.2) - i * 1.05) + 1) / 2);
        return (
          <div key={i} style={{
            width: 4.5, height: 4.5, borderRadius: '50%',
            background: C.amber, opacity: dotPulse,
          }} />
        );
      })}
    </div>
  );
};

// ─── Mac Screen / Editor ─────────────────────────────────────────────────────
const EditorScreen: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const screenSpring = easedSpring(frame, fps, T.SCREEN_IN, 140, 16);
  const screenScale = interpolate(screenSpring, [0, 1], [0.93, 1]);
  const screenOpacity = interpolate(screenSpring, [0, 0.4], [0, 1], { extrapolateRight: 'clamp' });

  // Determine which text to show
  const showingClean = frame >= T.CLEAN_WORDS_START;
  const showingRaw = frame >= T.WORDS_START && !showingClean;
  const shimmerActive = frame >= T.SHIMMER_START && frame < T.SHIMMER_END;

  // Shimmer sweep progress
  const shimmerProgress = interpolate(frame, [T.SHIMMER_START, T.SHIMMER_END], [0, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.inOut(Easing.cubic),
  });

  // Raw words stagger
  const STAGGER = 7; // frames between words
  const rawWordElements = RAW_WORDS.map((word, i) => {
    const wordStart = T.WORDS_START + i * STAGGER;
    if (frame < wordStart) return null;
    const { opacity, ty } = fadeSlideUp(frame, wordStart, 12, 14);
    const shimmerOnThis = shimmerActive && shimmerProgress > i / RAW_WORDS.length - 0.1 && shimmerProgress < i / RAW_WORDS.length + 0.3;
    const textOpacity = shimmerActive
      ? interpolate(shimmerProgress, [0.6, 1.0], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })
      : 1;

    return (
      <span key={i} style={{
        display: 'inline-block',
        opacity: opacity * textOpacity,
        transform: `translateY(${ty}px)`,
        marginRight: 8,
        color: `rgba(245,245,240,0.45)`,
        fontStyle: 'italic',
        filter: shimmerOnThis ? 'blur(1px)' : 'none',
        transition: 'filter 0.1s',
      }}>
        {word}
      </span>
    );
  });

  // Clean words stagger
  const CLEAN_STAGGER = 5;
  const cleanWordElements = CLEAN_WORDS.map((word, i) => {
    const wordStart = T.CLEAN_WORDS_START + i * CLEAN_STAGGER;
    if (frame < wordStart) return null;
    const localF = frame - wordStart;
    const wordSpring = spring({ frame: localF, fps, config: { stiffness: 260, damping: 22 } });
    const opacity = interpolate(wordSpring, [0, 0.5], [0, 1], { extrapolateRight: 'clamp' });
    const ty = interpolate(wordSpring, [0, 1], [16, 0]);
    const scale = interpolate(wordSpring, [0, 1], [0.9, 1]);
    return (
      <span key={i} style={{
        display: 'inline-block',
        opacity,
        transform: `translateY(${ty}px) scale(${scale})`,
        marginRight: 10,
        color: C.white,
        fontWeight: 600,
        fontSize: 28,
        letterSpacing: '-0.02em',
      }}>
        {word}
      </span>
    );
  });

  // Amber underline
  const underlineWidth = frame >= T.UNDERLINE_IN
    ? interpolate(frame, [T.UNDERLINE_IN, T.UNDERLINE_IN + 28], [0, 100], {
        extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic),
      })
    : 0;

  // Cursor blink (only before recording)
  const cursorVisible = frame >= T.CURSOR_START && frame < T.NOTCH_DROP + 10;
  const cursorBlink = Math.floor(frame / 18) % 2 === 0;

  // Shimmer overlay
  const shimmerX = interpolate(shimmerProgress, [0, 1], [-30, 130]);

  return (
    <div style={{
      transform: `scale(${screenScale})`,
      opacity: screenOpacity,
      width: '100%', height: '100%',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Menu bar */}
      <div style={{
        height: 36, background: C.menuBar,
        borderRadius: '14px 14px 0 0',
        display: 'flex', alignItems: 'center',
        padding: '0 16px',
        flexShrink: 0,
        borderBottom: `1px solid ${C.border}`,
      }}>
        {/* Traffic lights */}
        {['#FF5F56','#FFBD2E','#27C93F'].map((col, i) => (
          <div key={i} style={{ width: 11, height: 11, borderRadius: '50%', background: col, marginRight: 7, opacity: 0.85 }} />
        ))}
        {/* Window title */}
        <div style={{ flex: 1, textAlign: 'center', fontFamily: FONT, fontSize: 12, color: 'rgba(245,245,240,0.4)', fontWeight: 500 }}>
          Document.txt
        </div>
      </div>

      {/* Editor body */}
      <div style={{
        flex: 1,
        background: C.card,
        borderRadius: '0 0 14px 14px',
        padding: '32px 40px',
        boxSizing: 'border-box',
        position: 'relative',
        overflow: 'hidden',
      }}>
        {/* Line numbers */}
        <div style={{ position: 'absolute', left: 16, top: 32, fontFamily: 'SF Mono, Menlo, monospace', fontSize: 13, color: 'rgba(245,245,240,0.12)', lineHeight: '1.7' }}>
          {[1,2,3].map(n => <div key={n}>{n}</div>)}
        </div>

        {/* Text area */}
        <div style={{
          fontFamily: FONT,
          fontSize: 24,
          lineHeight: 1.65,
          minHeight: 120,
          position: 'relative',
        }}>
          {cursorVisible && (
            <span style={{
              display: 'inline-block',
              width: 2, height: 26, background: C.amber,
              borderRadius: 1, verticalAlign: 'middle',
              opacity: cursorBlink ? 1 : 0,
              boxShadow: `0 0 8px ${C.amber}`,
            }} />
          )}

          {/* Raw words */}
          {showingRaw && <span>{rawWordElements}</span>}

          {/* Shimmer during raw text */}
          {shimmerActive && (
            <div style={{
              position: 'absolute', inset: 0,
              background: `linear-gradient(90deg, transparent, rgba(249,115,22,0.18) 50%, transparent)`,
              backgroundSize: '200% 100%',
              left: `${shimmerX}%`, width: '60%',
              pointerEvents: 'none',
              borderRadius: 4,
            }} />
          )}

          {/* Clean words */}
          {showingClean && <div>{cleanWordElements}</div>}

          {/* Amber underline */}
          {showingClean && (
            <div style={{
              height: 2.5, marginTop: 8,
              width: `${underlineWidth}%`,
              background: `linear-gradient(90deg, ${C.amber}, rgba(249,115,22,0.35))`,
              borderRadius: 2,
              boxShadow: `0 0 8px rgba(249,115,22,0.3)`,
            }} />
          )}
        </div>

        {/* Bottom label — "pasted by Jottr" */}
        {frame >= T.UNDERLINE_IN + 30 && (() => {
          const { opacity } = fadeSlideUp(frame, T.UNDERLINE_IN + 30, 18, 10);
          return (
            <div style={{
              position: 'absolute', bottom: 20, right: 28,
              fontFamily: FONT, fontSize: 12,
              color: 'rgba(249,115,22,0.55)',
              letterSpacing: '0.04em',
              opacity,
              display: 'flex', alignItems: 'center', gap: 5,
            }}>
              <div style={{ width: 5, height: 5, borderRadius: '50%', background: C.amber, opacity: 0.7 }} />
              Pasted by Jottr
            </div>
          );
        })()}
      </div>
    </div>
  );
};

// ─── Root Composition ─────────────────────────────────────────────────────────
export const JottrDemo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Overall fade out
  const fadeOut = interpolate(frame, [T.TOTAL - 30, T.TOTAL], [1, 0], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.in(Easing.cubic),
  });

  // Screen card spring
  const cardSpring = easedSpring(frame, fps, T.SCREEN_IN, 130, 15);
  const cardY = interpolate(cardSpring, [0, 1], [80, 0]);

  return (
    <AbsoluteFill style={{ background: C.bg, fontFamily: FONT, overflow: 'hidden' }}>

      {/* Jottr wordmark — slides in top-left */}
      {(() => {
        const { opacity, ty } = fadeSlideUp(frame, 4, 20, 12);
        return (
          <div style={{
            position: 'absolute', top: 32, left: 48, zIndex: 200,
            fontFamily: FONT, fontSize: 20, fontWeight: 700,
            color: C.amber, letterSpacing: '-0.01em',
            opacity, transform: `translateY(${ty}px)`,
          }}>
            Jottr
          </div>
        );
      })()}

      {/* Hint label — bottom */}
      {frame >= T.CURSOR_START && frame < T.NOTCH_DROP && (() => {
        const { opacity } = fadeSlideUp(frame, T.CURSOR_START, 16, 10);
        const exitOpacity = interpolate(frame, [T.NOTCH_DROP - 14, T.NOTCH_DROP], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
        return (
          <div style={{
            position: 'absolute', bottom: 48, left: 0, right: 0,
            display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 10,
            opacity: opacity * exitOpacity, zIndex: 10,
          }}>
            <div style={{
              fontFamily: FONT, fontSize: 14, color: C.muted,
              background: 'rgba(255,255,255,0.06)', borderRadius: 8,
              padding: '7px 14px', border: `1px solid ${C.border}`,
              letterSpacing: '0.02em',
            }}>
              Hold <span style={{ color: C.amber, fontWeight: 600 }}>Fn</span> to dictate
            </div>
          </div>
        );
      })()}

      {/* Fn key "press" indicator during recording */}
      {frame >= T.NOTCH_DROP && frame < T.NOTCH_EXIT && (() => {
        const { opacity } = fadeSlideUp(frame, T.NOTCH_DROP, 12, 8);
        return (
          <div style={{
            position: 'absolute', bottom: 48, left: 0, right: 0,
            display: 'flex', justifyContent: 'center',
            opacity, zIndex: 10,
          }}>
            <div style={{
              fontFamily: FONT, fontSize: 13, color: C.amber,
              background: 'rgba(249,115,22,0.1)',
              border: `1px solid rgba(249,115,22,0.3)`,
              borderRadius: 8, padding: '6px 14px',
              letterSpacing: '0.03em',
            }}>
              Fn ↓ recording...
            </div>
          </div>
        );
      })()}

      {/* Mac screen card */}
      <div style={{
        position: 'absolute',
        top: 52, left: 60, right: 60, bottom: 72,
        transform: `translateY(${cardY}px)`,
        opacity: fadeOut,
        borderRadius: 14,
        boxShadow: '0 32px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.06)',
        overflow: 'visible',
      }}>
        {/* Notch overlay sits above the card's menu bar */}
        <NotchOverlay frame={frame} fps={fps} />
        <TranscribingDots frame={frame} fps={fps} />
        <EditorScreen frame={frame} fps={fps} />
      </div>

    </AbsoluteFill>
  );
};
