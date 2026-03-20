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
  card: '#1E1E20',
  border: 'rgba(255,255,255,0.07)',
  amber: '#F97316',
  amberDim: 'rgba(249,115,22,0.15)',
  white: '#F5F5F0',
  muted: 'rgba(245,245,240,0.38)',
  menuBar: '#161618',
  bubble: '#2C2C2E',
  bubbleOut: '#F97316',
};
const FONT = "system-ui,-apple-system,'SF Pro Display','Helvetica Neue',sans-serif";

// ─── Timing (frames @ 30fps = 14s) ────────────────────────────────────────
const T = {
  SCREEN_IN: 0,
  CHAT_IN: 14,
  CURSOR_START: 40,

  NOTCH_DROP: 68,
  WAVEFORM_START: 82,

  WORDS_START: 90,
  WORDS_END: 178,

  NOTCH_EXIT: 182,
  TRANSCRIBING_IN: 190,
  TRANSCRIBING_OUT: 226,

  SHIMMER_START: 224,
  SHIMMER_END: 264,

  CLEAN_WORDS_START: 258,
  UNDERLINE_IN: 288,

  TOTAL: 420,
};

// Raw spoken words, clean result
const RAW_WORDS = ['yeah', 'uh', 'actually', 'I', 'might', 'be', 'like', '20', 'minutes', 'late', 'just', 'heads', 'up'];
const CLEAN_WORDS = ['Yeah', 'but', 'just', 'a', 'heads', 'up', 'I', 'might', 'be', '20', 'minutes', 'late.'];

// ─── Helpers ─────────────────────────────────────────────────────────────────
function easedSpring(frame: number, fps: number, delay = 0, stiffness = 160, damping = 18) {
  return spring({ frame: Math.max(0, frame - delay), fps, config: { stiffness, damping } });
}

function fadeSlideUp(frame: number, from: number, duration = 16, distance = 18) {
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

// ─── Notch Overlay ───────────────────────────────────────────────────────────
const NotchOverlay: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const localIn = frame - T.NOTCH_DROP;
  const localOut = frame - T.NOTCH_EXIT;

  const dropIn = spring({ frame: Math.max(0, localIn), fps, config: { stiffness: 220, damping: 14 } });
  const slideOut = frame >= T.NOTCH_EXIT
    ? interpolate(localOut, [0, 14], [0, 1], { extrapolateRight: 'clamp', easing: Easing.in(Easing.cubic) })
    : 0;

  const visible = frame >= T.NOTCH_DROP && frame < T.NOTCH_EXIT + 16;
  if (!visible) return null;

  const translateY = interpolate(dropIn, [0, 1], [-52, 0]) * (1 - slideOut);
  const opacity = interpolate(dropIn, [0, 0.3], [0, 1], { extrapolateRight: 'clamp' }) * (1 - slideOut);

  const waveLocal = frame - T.WAVEFORM_START;
  // Smaller bar heights so they stay within the 34px notch pill
  const BASE_H = [6, 9, 13, 10, 17, 11, 8, 12, 7];
  const pulseOpacity = 0.65 + 0.35 * Math.sin(frame * 0.15);

  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: '50%',
        transform: `translateX(-50%) translateY(${translateY}px)`,
        opacity,
        zIndex: 100,
        width: 210,
        height: 32,
        background: 'black',
        borderRadius: '0 0 18px 18px',
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
      {/* Pulsing amber dot */}
      <div style={{
        width: 6, height: 6, borderRadius: '50%',
        background: C.amber,
        opacity: pulseOpacity,
        flexShrink: 0,
        boxShadow: `0 0 6px ${C.amber}`,
      }} />

      {/* Waveform bars — smaller and fully contained */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 2, flex: 1, justifyContent: 'center' }}>
        {BASE_H.map((bh, i) => {
          const phase = (waveLocal / 7 + i * 0.65) * Math.PI;
          const wave = Math.sin(phase) * 0.45 + Math.sin(phase * 1.8 + i) * 0.25;
          const h = Math.max(3, Math.min(20, bh + wave * 5));
          return (
            <div key={i} style={{
              width: 2.5, height: h, borderRadius: 2,
              background: C.amber,
              boxShadow: `0 0 3px rgba(249,115,22,0.35)`,
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

// ─── Transcribing dots ────────────────────────────────────────────────────────
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
      width: 52, height: 26,
      background: 'black',
      borderRadius: '0 0 13px 13px',
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5,
      boxShadow: '0 4px 20px rgba(0,0,0,0.5)',
    }}>
      {[0, 1, 2].map(i => {
        const dotPulse = 0.3 + 0.7 * ((Math.sin((frame * 0.2) - i * 1.05) + 1) / 2);
        return (
          <div key={i} style={{
            width: 4, height: 4, borderRadius: '50%',
            background: C.amber, opacity: dotPulse,
          }} />
        );
      })}
    </div>
  );
};

// ─── Chat / Message Screen ────────────────────────────────────────────────────
const MessageScreen: React.FC<{ frame: number; fps: number }> = ({ frame, fps }) => {
  const screenSpring = easedSpring(frame, fps, T.SCREEN_IN, 140, 16);
  const screenScale = interpolate(screenSpring, [0, 1], [0.93, 1]);
  const screenOpacity = interpolate(screenSpring, [0, 0.4], [0, 1], { extrapolateRight: 'clamp' });

  // Chat bubbles animate in with screen
  const chatIn = easedSpring(frame, fps, T.CHAT_IN, 120, 16);
  const chatOpacity = interpolate(chatIn, [0, 0.5], [0, 1], { extrapolateRight: 'clamp' });
  const chatTy = interpolate(chatIn, [0, 1], [16, 0]);

  const showingClean = frame >= T.CLEAN_WORDS_START;
  const showingRaw = frame >= T.WORDS_START && !showingClean;
  const shimmerActive = frame >= T.SHIMMER_START && frame < T.SHIMMER_END;

  const shimmerProgress = interpolate(frame, [T.SHIMMER_START, T.SHIMMER_END], [0, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.inOut(Easing.cubic),
  });

  // Raw words staggered in compose box
  const STAGGER = 6;
  const rawWordElements = RAW_WORDS.map((word, i) => {
    const wordStart = T.WORDS_START + i * STAGGER;
    if (frame < wordStart) return null;
    const { opacity, ty } = fadeSlideUp(frame, wordStart, 10, 10);
    const textOpacity = shimmerActive
      ? interpolate(shimmerProgress, [0.6, 1.0], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' })
      : 1;
    const shimmerOnThis = shimmerActive && shimmerProgress > i / RAW_WORDS.length - 0.1 && shimmerProgress < i / RAW_WORDS.length + 0.3;
    return (
      <span key={i} style={{
        display: 'inline-block',
        opacity: opacity * textOpacity,
        transform: `translateY(${ty}px)`,
        marginRight: 6,
        color: 'rgba(245,245,240,0.45)',
        fontStyle: 'italic',
        filter: shimmerOnThis ? 'blur(0.8px)' : 'none',
      }}>
        {word}
      </span>
    );
  });

  // Clean words spring in
  const CLEAN_STAGGER = 5;
  const cleanWordElements = CLEAN_WORDS.map((word, i) => {
    const wordStart = T.CLEAN_WORDS_START + i * CLEAN_STAGGER;
    if (frame < wordStart) return null;
    const localF = frame - wordStart;
    const wordSpring = spring({ frame: localF, fps, config: { stiffness: 280, damping: 22 } });
    const opacity = interpolate(wordSpring, [0, 0.5], [0, 1], { extrapolateRight: 'clamp' });
    const ty = interpolate(wordSpring, [0, 1], [14, 0]);
    const scale = interpolate(wordSpring, [0, 1], [0.88, 1]);
    return (
      <span key={i} style={{
        display: 'inline-block',
        opacity,
        transform: `translateY(${ty}px) scale(${scale})`,
        marginRight: 7,
        color: C.white,
        fontWeight: 500,
      }}>
        {word}
      </span>
    );
  });

  // Amber underline sweep
  const underlineWidth = frame >= T.UNDERLINE_IN
    ? interpolate(frame, [T.UNDERLINE_IN, T.UNDERLINE_IN + 26], [0, 100], {
        extrapolateRight: 'clamp', easing: Easing.out(Easing.cubic),
      })
    : 0;

  const cursorVisible = frame >= T.CURSOR_START && frame < T.NOTCH_DROP + 8;
  const cursorBlink = Math.floor(frame / 18) % 2 === 0;

  const shimmerX = interpolate(shimmerProgress, [0, 1], [-30, 130]);

  return (
    <div style={{
      transform: `scale(${screenScale})`,
      opacity: screenOpacity,
      width: '100%', height: '100%',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Window chrome */}
      <div style={{
        height: 40, background: C.menuBar,
        borderRadius: '14px 14px 0 0',
        display: 'flex', alignItems: 'center',
        padding: '0 16px',
        flexShrink: 0,
        borderBottom: `1px solid ${C.border}`,
        gap: 8,
      }}>
        {['#FF5F56','#FFBD2E','#27C93F'].map((col, i) => (
          <div key={i} style={{ width: 11, height: 11, borderRadius: '50%', background: col, opacity: 0.85 }} />
        ))}
        {/* Contact name / channel */}
        <div style={{
          flex: 1, textAlign: 'center', fontFamily: FONT,
          fontSize: 13, color: 'rgba(245,245,240,0.55)', fontWeight: 600,
          letterSpacing: '-0.01em',
        }}>
          Jamie
        </div>
        {/* Avatar placeholder */}
        <div style={{
          width: 24, height: 24, borderRadius: '50%',
          background: 'linear-gradient(135deg, #6366f1, #8b5cf6)',
          flexShrink: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: FONT, fontSize: 11, fontWeight: 700, color: '#fff',
        }}>J</div>
      </div>

      {/* Chat body */}
      <div style={{
        flex: 1,
        background: C.card,
        borderRadius: '0 0 14px 14px',
        display: 'flex', flexDirection: 'column',
        overflow: 'hidden',
      }}>
        {/* Message thread */}
        <div
          style={{
            flex: 1,
            padding: '24px 24px 16px',
            display: 'flex', flexDirection: 'column',
            justifyContent: 'flex-end', gap: 10,
            opacity: chatOpacity,
            transform: `translateY(${chatTy}px)`,
          }}
        >
          {/* Incoming bubble */}
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8 }}>
            <div style={{
              width: 28, height: 28, borderRadius: '50%',
              background: 'linear-gradient(135deg, #6366f1, #8b5cf6)',
              flexShrink: 0,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: FONT, fontSize: 12, fontWeight: 700, color: '#fff',
            }}>J</div>
            <div style={{
              background: C.bubble,
              borderRadius: '16px 16px 16px 4px',
              padding: '10px 14px',
              maxWidth: '60%',
            }}>
              <div style={{ fontFamily: FONT, fontSize: 15, color: C.white, lineHeight: 1.45 }}>
                You still coming tonight?
              </div>
            </div>
          </div>

          {/* Outgoing bubble (older reply) */}
          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <div style={{
              background: '#3A3A3C',
              borderRadius: '16px 16px 4px 16px',
              padding: '10px 14px',
              maxWidth: '55%',
            }}>
              <div style={{ fontFamily: FONT, fontSize: 15, color: C.white, lineHeight: 1.45 }}>
                Should be there
              </div>
            </div>
          </div>

          {/* Timestamp */}
          <div style={{
            textAlign: 'center', fontFamily: FONT,
            fontSize: 11, color: 'rgba(245,245,240,0.25)',
            letterSpacing: '0.02em',
          }}>
            Just now
          </div>
        </div>

        {/* Compose area */}
        <div style={{
          borderTop: `1px solid rgba(255,255,255,0.06)`,
          padding: '12px 20px 16px',
          background: '#1A1A1C',
          position: 'relative',
        }}>
          <div style={{
            background: '#2C2C2E',
            borderRadius: 22,
            padding: '11px 18px',
            minHeight: 44,
            display: 'flex', alignItems: 'center',
            border: `1px solid ${frame >= T.NOTCH_DROP && frame < T.NOTCH_EXIT + 10
              ? 'rgba(249,115,22,0.4)'
              : 'rgba(255,255,255,0.06)'}`,
            boxShadow: frame >= T.NOTCH_DROP && frame < T.NOTCH_EXIT + 10
              ? '0 0 0 3px rgba(249,115,22,0.08)'
              : 'none',
            transition: 'border-color 0.2s',
            position: 'relative',
            overflow: 'hidden',
          }}>
            {/* Placeholder */}
            {frame < T.CURSOR_START && (
              <div style={{ fontFamily: FONT, fontSize: 15, color: 'rgba(245,245,240,0.2)' }}>
                Message Jamie...
              </div>
            )}

            {/* Blinking cursor */}
            {cursorVisible && (
              <span style={{
                display: 'inline-block',
                width: 2, height: 18, background: C.amber,
                borderRadius: 1, verticalAlign: 'middle',
                opacity: cursorBlink ? 1 : 0,
                boxShadow: `0 0 6px ${C.amber}`,
              }} />
            )}

            {/* Raw dictated words */}
            {showingRaw && (
              <div style={{ fontFamily: FONT, fontSize: 15, lineHeight: 1.5, flexWrap: 'wrap', display: 'flex' }}>
                {rawWordElements}
              </div>
            )}

            {/* Shimmer sweep */}
            {shimmerActive && (
              <div style={{
                position: 'absolute', inset: 0,
                background: `linear-gradient(90deg, transparent, rgba(249,115,22,0.16) 50%, transparent)`,
                left: `${shimmerX}%`, width: '60%',
                pointerEvents: 'none',
              }} />
            )}

            {/* Clean words */}
            {showingClean && (
              <div style={{ fontFamily: FONT, fontSize: 15, lineHeight: 1.5, flexWrap: 'wrap', display: 'flex' }}>
                {cleanWordElements}
              </div>
            )}

            {/* Send button (appears after clean text) */}
            {showingClean && (() => {
              const btnSpring = easedSpring(frame, fps, T.CLEAN_WORDS_START + 20, 300, 20);
              const btnOpacity = interpolate(btnSpring, [0, 0.6], [0, 1], { extrapolateRight: 'clamp' });
              const btnScale = interpolate(btnSpring, [0, 1], [0.5, 1]);
              return (
                <div style={{
                  marginLeft: 'auto', flexShrink: 0,
                  width: 28, height: 28, borderRadius: '50%',
                  background: C.amber,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  opacity: btnOpacity,
                  transform: `scale(${btnScale})`,
                  boxShadow: `0 0 12px rgba(249,115,22,0.4)`,
                }}>
                  <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                    <path d="M2 7h10M8 3l4 4-4 4" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </div>
              );
            })()}
          </div>

          {/* Amber underline beneath compose box */}
          {showingClean && (
            <div style={{
              height: 2, marginTop: 8, marginLeft: 4,
              width: `${underlineWidth}%`,
              background: `linear-gradient(90deg, ${C.amber}, rgba(249,115,22,0.2))`,
              borderRadius: 2,
            }} />
          )}
        </div>
      </div>
    </div>
  );
};

// ─── Root Composition ─────────────────────────────────────────────────────────
export const JottrDemo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const fadeOut = interpolate(frame, [T.TOTAL - 30, T.TOTAL], [1, 0], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.in(Easing.cubic),
  });

  const cardSpring = easedSpring(frame, fps, T.SCREEN_IN, 130, 15);
  const cardY = interpolate(cardSpring, [0, 1], [80, 0]);

  // Jottr wordmark
  const { opacity: logoOpacity, ty: logoTy } = fadeSlideUp(frame, 4, 20, 12);

  return (
    <AbsoluteFill style={{ background: C.bg, fontFamily: FONT, overflow: 'hidden' }}>

      {/* Jottr wordmark — higher up so card doesn't overlap */}
      <div style={{
        position: 'absolute', top: 16, left: 48, zIndex: 200,
        fontFamily: FONT, fontSize: 20, fontWeight: 700,
        color: C.amber, letterSpacing: '-0.01em',
        opacity: logoOpacity, transform: `translateY(${logoTy}px)`,
      }}>
        Jottr
      </div>

      {/* "Hold Fn to dictate" hint */}
      {frame >= T.CURSOR_START && frame < T.NOTCH_DROP && (() => {
        const { opacity } = fadeSlideUp(frame, T.CURSOR_START, 16, 10);
        const exitOpacity = interpolate(frame, [T.NOTCH_DROP - 14, T.NOTCH_DROP], [1, 0], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' });
        return (
          <div style={{
            position: 'absolute', bottom: 48, left: 0, right: 0,
            display: 'flex', justifyContent: 'center', alignItems: 'center',
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

      {/* Recording indicator */}
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
              Fn ↓  recording...
            </div>
          </div>
        );
      })()}

      {/* "Better dictation with Jottr" label */}
      {frame >= T.UNDERLINE_IN + 30 && (() => {
        const { opacity } = fadeSlideUp(frame, T.UNDERLINE_IN + 30, 18, 10);
        return (
          <div style={{
            position: 'absolute', bottom: 44, left: 0, right: 0,
            display: 'flex', justifyContent: 'center',
            opacity, zIndex: 10,
          }}>
            <div style={{
              fontFamily: FONT, fontSize: 13,
              color: 'rgba(249,115,22,0.6)',
              letterSpacing: '0.03em',
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
              <div style={{ width: 5, height: 5, borderRadius: '50%', background: C.amber, opacity: 0.8 }} />
              Better dictation with Jottr
            </div>
          </div>
        );
      })()}

      {/* Screen card */}
      <div style={{
        position: 'absolute',
        top: 44, left: 60, right: 60, bottom: 80,
        transform: `translateY(${cardY}px)`,
        opacity: fadeOut,
        borderRadius: 14,
        boxShadow: '0 32px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.06)',
        overflow: 'visible',
      }}>
        <NotchOverlay frame={frame} fps={fps} />
        <TranscribingDots frame={frame} fps={fps} />
        <MessageScreen frame={frame} fps={fps} />
      </div>

    </AbsoluteFill>
  );
};
