import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from 'remotion';

const COLORS = {
  bg: '#1C1C1E',
  amber: '#F97316',
  white: '#F5F5F0',
};

const FONT = "system-ui, -apple-system, 'Helvetica Neue', sans-serif";

// Phase timings (frames at 30fps = 10s total)
// P1 cursor:     0 – 70
// P2 waveform:  60 – 150
// P3 raw text: 140 – 200
// P4 processing:195 – 240
// P5 clean:    235 – 300

const CursorPhase: React.FC<{frame: number}> = ({frame}) => {
  const blink = Math.floor(frame / 20) % 2 === 0 ? 1 : 0;
  const opacity = interpolate(frame, [0, 14], [0, 1], {extrapolateRight: 'clamp'});
  const exitOpacity = interpolate(frame, [55, 70], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

  return (
    <AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', opacity: opacity * exitOpacity}}>
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 24}}>
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
          <div style={{width: 2, height: 32, background: COLORS.amber, borderRadius: 2, opacity: blink}} />
        </div>
        <div style={{fontFamily: FONT, fontSize: 18, color: 'rgba(245,245,240,0.35)', letterSpacing: '0.02em'}}>
          Hold to dictate...
        </div>
      </div>
    </AbsoluteFill>
  );
};

const WaveformPhase: React.FC<{frame: number}> = ({frame}) => {
  const localFrame = frame - 60;
  const enterOpacity = interpolate(localFrame, [0, 18], [0, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  const exitOpacity = interpolate(localFrame, [72, 90], [1, 0], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.in(Easing.cubic),
  });
  const opacity = enterOpacity * exitOpacity;

  const barCount = 9;
  const baseHeights = [28, 48, 64, 52, 72, 56, 44, 60, 32];

  return (
    <AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', opacity}}>
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 32}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 8, height: 100}}>
          {Array.from({length: barCount}).map((_, i) => {
            const phase = (localFrame / 10 + i * 0.7) * Math.PI;
            const wave = Math.sin(phase) * 0.4 + Math.sin(phase * 1.7 + i) * 0.3;
            const height = baseHeights[i] + wave * 30;
            const clampedHeight = Math.max(8, Math.min(90, height));
            return (
              <div
                key={i}
                style={{
                  width: 10, height: clampedHeight, borderRadius: 5,
                  background: COLORS.amber,
                  boxShadow: `0 0 12px rgba(249,115,22,0.5)`,
                }}
              />
            );
          })}
        </div>
        <div style={{fontFamily: FONT, fontSize: 16, color: COLORS.amber, letterSpacing: '0.08em', fontWeight: 500, textTransform: 'uppercase' as const}}>
          Recording...
        </div>
      </div>
    </AbsoluteFill>
  );
};

const RawTextPhase: React.FC<{frame: number}> = ({frame}) => {
  const localFrame = frame - 140;
  const enterOpacity = interpolate(localFrame, [0, 18], [0, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  const exitOpacity = interpolate(localFrame, [45, 60], [1, 0], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
  });

  return (
    <AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', opacity: enterOpacity * exitOpacity}}>
      <div
        style={{
          width: 700, padding: '32px 40px', boxSizing: 'border-box',
          borderRadius: 16,
          border: `1.5px solid rgba(245,245,240,0.12)`,
          background: 'rgba(245,245,240,0.04)',
        }}
      >
        <div style={{fontFamily: FONT, fontSize: 24, color: `rgba(245,245,240,0.5)`, lineHeight: 1.6, fontStyle: 'italic'}}>
          um so basically uh the meeting went really well you know i think
        </div>
      </div>
    </AbsoluteFill>
  );
};

const ProcessingPhase: React.FC<{frame: number}> = ({frame}) => {
  const localFrame = frame - 195;
  const progress = interpolate(localFrame, [0, 45], [0, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
  });
  const intensity = Math.sin(progress * Math.PI);

  return (
    <AbsoluteFill style={{justifyContent: 'center', alignItems: 'center'}}>
      <div style={{position: 'absolute', inset: 0, background: `radial-gradient(ellipse at center, rgba(249,115,22,${intensity * 0.15}) 0%, transparent 70%)`}} />
      <div
        style={{
          width: 700, padding: '32px 40px', boxSizing: 'border-box',
          borderRadius: 16,
          border: `1.5px solid rgba(249,115,22,${0.12 + intensity * 0.5})`,
          background: `rgba(249,115,22,${intensity * 0.06})`,
          boxShadow: `0 0 ${40 * intensity}px rgba(249,115,22,${intensity * 0.3})`,
          overflow: 'hidden', position: 'relative',
        }}
      >
        <div
          style={{
            position: 'absolute', top: 0,
            left: `${progress * 130 - 30}%`,
            width: '30%', height: '100%',
            background: 'linear-gradient(90deg, transparent, rgba(249,115,22,0.25), transparent)',
          }}
        />
        <div style={{fontFamily: FONT, fontSize: 24, color: `rgba(245,245,240,${0.5 + intensity * 0.3})`, lineHeight: 1.6, fontStyle: 'italic', filter: `blur(${intensity * 1.5}px)`}}>
          um so basically uh the meeting went really well you know i think
        </div>
      </div>
    </AbsoluteFill>
  );
};

const CleanTextPhase: React.FC<{frame: number}> = ({frame}) => {
  const localFrame = frame - 235;

  const opacity = interpolate(localFrame, [0, 22], [0, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });
  const scale = interpolate(localFrame, [0, 22], [0.96, 1], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.out(Easing.back(1.2)),
  });
  const underlineWidth = interpolate(localFrame, [14, 42], [0, 100], {
    extrapolateLeft: 'clamp', extrapolateRight: 'clamp',
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', opacity}}>
      <div style={{transform: `scale(${scale})`, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12}}>
        <div style={{fontFamily: FONT, fontSize: 44, color: COLORS.white, fontWeight: 600, letterSpacing: '-0.02em', textAlign: 'center'}}>
          The meeting went well.
        </div>
        <div
          style={{
            height: 3,
            width: `${underlineWidth}%`,
            background: `linear-gradient(90deg, ${COLORS.amber}, rgba(249,115,22,0.4))`,
            borderRadius: 2,
            alignSelf: 'flex-start',
          }}
        />
        <div style={{fontFamily: FONT, fontSize: 15, color: 'rgba(245,245,240,0.4)', letterSpacing: '0.05em', marginTop: 4}}>
          Cleaned by Jottr
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const JottrDemo: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{background: COLORS.bg, fontFamily: FONT}}>
      {/* Wordmark */}
      <div style={{position: 'absolute', top: 32, left: 40, fontFamily: FONT, fontSize: 22, fontWeight: 700, color: COLORS.amber, letterSpacing: '-0.01em', zIndex: 10}}>
        Jottr
      </div>

      {frame <= 72 && <CursorPhase frame={frame} />}
      {frame >= 60 && frame <= 152 && <WaveformPhase frame={frame} />}
      {frame >= 140 && frame <= 202 && <RawTextPhase frame={frame} />}
      {frame >= 195 && frame <= 242 && <ProcessingPhase frame={frame} />}
      {frame >= 235 && <CleanTextPhase frame={frame} />}
    </AbsoluteFill>
  );
};
