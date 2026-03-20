import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
  Easing,
} from 'remotion';

const COLORS = {
  bg: '#1C1C1E',
  amber: '#F97316',
  white: '#F5F5F0',
};

const FONT = "system-ui, -apple-system, 'Helvetica Neue', sans-serif";

// Phase 1 (0-30): Blinking cursor
const CursorPhase: React.FC<{frame: number}> = ({frame}) => {
  const blink = Math.floor(frame / 15) % 2 === 0 ? 1 : 0;
  const opacity = interpolate(frame, [0, 10], [0, 1], {extrapolateRight: 'clamp'});

  return (
    <AbsoluteFill
      style={{
        justifyContent: 'center',
        alignItems: 'center',
        opacity,
      }}
    >
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 24,
        }}
      >
        {/* Text area */}
        <div
          style={{
            width: 700,
            height: 120,
            borderRadius: 16,
            border: `1.5px solid rgba(245,245,240,0.12)`,
            background: 'rgba(245,245,240,0.04)',
            display: 'flex',
            alignItems: 'center',
            padding: '0 28px',
            boxSizing: 'border-box',
          }}
        >
          <div
            style={{
              width: 2,
              height: 32,
              background: COLORS.amber,
              borderRadius: 2,
              opacity: blink,
            }}
          />
        </div>
        {/* Hint */}
        <div
          style={{
            fontFamily: FONT,
            fontSize: 18,
            color: 'rgba(245,245,240,0.35)',
            letterSpacing: '0.02em',
            fontWeight: 400,
          }}
        >
          Hold to dictate...
        </div>
      </div>
    </AbsoluteFill>
  );
};

// Phase 2 (30-70): Waveform bars
const WaveformPhase: React.FC<{frame: number; startFrame: number}> = ({frame, startFrame}) => {
  const localFrame = frame - startFrame;
  const enterProgress = interpolate(localFrame, [0, 15], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  const exitProgress = interpolate(localFrame, [25, 40], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.in(Easing.cubic),
  });
  const opacity = enterProgress * (1 - exitProgress);

  const barCount = 9;
  const baseHeights = [28, 48, 64, 52, 72, 56, 44, 60, 32];

  return (
    <AbsoluteFill
      style={{
        justifyContent: 'center',
        alignItems: 'center',
        opacity,
      }}
    >
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 32,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            height: 100,
          }}
        >
          {Array.from({length: barCount}).map((_, i) => {
            const phase = (localFrame / 6 + i * 0.7) * Math.PI;
            const wave = Math.sin(phase) * 0.4 + Math.sin(phase * 1.7 + i) * 0.3;
            const height = baseHeights[i] + wave * 30;
            const clampedHeight = Math.max(8, Math.min(90, height));

            return (
              <div
                key={i}
                style={{
                  width: 10,
                  height: clampedHeight,
                  borderRadius: 5,
                  background: COLORS.amber,
                  transition: 'height 0.05s',
                  boxShadow: `0 0 12px rgba(249,115,22,0.5)`,
                }}
              />
            );
          })}
        </div>
        <div
          style={{
            fontFamily: FONT,
            fontSize: 16,
            color: COLORS.amber,
            letterSpacing: '0.08em',
            fontWeight: 500,
            textTransform: 'uppercase',
          }}
        >
          Recording...
        </div>
      </div>
    </AbsoluteFill>
  );
};

// Phase 3 (70-100): Raw messy text
const RawTextPhase: React.FC<{frame: number; startFrame: number}> = ({frame, startFrame}) => {
  const localFrame = frame - startFrame;
  const opacity = interpolate(localFrame, [0, 15], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: 'center',
        alignItems: 'center',
        opacity,
      }}
    >
      <div
        style={{
          width: 700,
          padding: '32px 40px',
          boxSizing: 'border-box',
          borderRadius: 16,
          border: `1.5px solid rgba(245,245,240,0.12)`,
          background: 'rgba(245,245,240,0.04)',
        }}
      >
        <div
          style={{
            fontFamily: FONT,
            fontSize: 24,
            color: `rgba(245,245,240,0.5)`,
            lineHeight: 1.6,
            fontWeight: 400,
            fontStyle: 'italic',
          }}
        >
          um so basically uh the meeting went really well you know i think
        </div>
      </div>
    </AbsoluteFill>
  );
};

// Phase 4 (100-120): Amber shimmer/processing flash
const ProcessingPhase: React.FC<{frame: number; startFrame: number}> = ({frame, startFrame}) => {
  const localFrame = frame - startFrame;
  const progress = interpolate(localFrame, [0, 20], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // Bell curve: ramp up then down
  const intensity = Math.sin(progress * Math.PI);

  return (
    <AbsoluteFill
      style={{
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      {/* Background flash */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(ellipse at center, rgba(249,115,22,${intensity * 0.15}) 0%, transparent 70%)`,
        }}
      />
      <div
        style={{
          width: 700,
          padding: '32px 40px',
          boxSizing: 'border-box',
          borderRadius: 16,
          border: `1.5px solid rgba(249,115,22,${0.12 + intensity * 0.5})`,
          background: `rgba(249,115,22,${intensity * 0.06})`,
          boxShadow: `0 0 ${40 * intensity}px rgba(249,115,22,${intensity * 0.3})`,
          overflow: 'hidden',
          position: 'relative',
        }}
      >
        {/* Shimmer sweep */}
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: `${progress * 130 - 30}%`,
            width: '30%',
            height: '100%',
            background:
              'linear-gradient(90deg, transparent, rgba(249,115,22,0.25), transparent)',
            pointerEvents: 'none',
          }}
        />
        <div
          style={{
            fontFamily: FONT,
            fontSize: 24,
            color: `rgba(245,245,240,${0.5 + intensity * 0.3})`,
            lineHeight: 1.6,
            fontWeight: 400,
            fontStyle: 'italic',
            filter: `blur(${intensity * 1.5}px)`,
          }}
        >
          um so basically uh the meeting went really well you know i think
        </div>
      </div>
    </AbsoluteFill>
  );
};

// Phase 5 (120-150): Clean polished text
const CleanTextPhase: React.FC<{frame: number; startFrame: number}> = ({frame, startFrame}) => {
  const {fps} = useVideoConfig();
  const localFrame = frame - startFrame;

  const opacity = interpolate(localFrame, [0, 18], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  const scale = interpolate(localFrame, [0, 18], [0.96, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.back(1.2)),
  });

  const underlineWidth = interpolate(localFrame, [10, 28], [0, 100], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill
      style={{
        justifyContent: 'center',
        alignItems: 'center',
        opacity,
      }}
    >
      <div
        style={{
          transform: `scale(${scale})`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 12,
        }}
      >
        <div
          style={{
            fontFamily: FONT,
            fontSize: 44,
            color: COLORS.white,
            fontWeight: 600,
            letterSpacing: '-0.02em',
            textAlign: 'center',
          }}
        >
          The meeting went well.
        </div>
        {/* Amber underline */}
        <div
          style={{
            height: 3,
            width: `${underlineWidth}%`,
            background: `linear-gradient(90deg, ${COLORS.amber}, rgba(249,115,22,0.4))`,
            borderRadius: 2,
            alignSelf: 'flex-start',
            marginLeft: '0',
          }}
        />
        <div
          style={{
            fontFamily: FONT,
            fontSize: 15,
            color: 'rgba(245,245,240,0.4)',
            letterSpacing: '0.05em',
            fontWeight: 400,
            marginTop: 4,
          }}
        >
          Cleaned by Jottr AI
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const JottrDemo: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill
      style={{
        background: COLORS.bg,
        fontFamily: FONT,
      }}
    >
      {/* Wordmark */}
      <div
        style={{
          position: 'absolute',
          top: 32,
          left: 40,
          fontFamily: FONT,
          fontSize: 22,
          fontWeight: 700,
          color: COLORS.amber,
          letterSpacing: '-0.01em',
          zIndex: 10,
        }}
      >
        Jottr
      </div>

      {/* Phase 1: Cursor (0-40) */}
      {frame <= 40 && <CursorPhase frame={frame} />}

      {/* Phase 2: Waveform (30-70) */}
      {frame >= 30 && frame <= 75 && (
        <WaveformPhase frame={frame} startFrame={30} />
      )}

      {/* Phase 3: Raw text (70-105) */}
      {frame >= 70 && frame <= 105 && (
        <RawTextPhase frame={frame} startFrame={70} />
      )}

      {/* Phase 4: Processing (100-120) */}
      {frame >= 100 && frame <= 122 && (
        <ProcessingPhase frame={frame} startFrame={100} />
      )}

      {/* Phase 5: Clean text (120-150) */}
      {frame >= 120 && <CleanTextPhase frame={frame} startFrame={120} />}
    </AbsoluteFill>
  );
};
