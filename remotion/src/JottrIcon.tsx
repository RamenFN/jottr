import React from "react";
import { AbsoluteFill } from "remotion";

export const JottrIcon: React.FC = () => {
  // Canvas is 1024x1024
  // Napkin: 750x750, centered at (512, 512), so top-left at (137, 137)
  const napkinX = 137;
  const napkinY = 137;
  const napkinW = 750;
  const napkinH = 750;
  const napkinRadius = 24;

  // Corner fold: bottom-right corner, ~90px triangle
  const foldSize = 90;
  const napkinRight = napkinX + napkinW;
  const napkinBottom = napkinY + napkinH;

  // Napkin shape as a polygon path with a clipped bottom-right corner
  // Using clipPath on a rect to create the folded corner effect
  const napkinPath = `
    M ${napkinX + napkinRadius} ${napkinY}
    L ${napkinRight - napkinRadius} ${napkinY}
    Q ${napkinRight} ${napkinY} ${napkinRight} ${napkinY + napkinRadius}
    L ${napkinRight} ${napkinBottom - foldSize}
    L ${napkinRight - foldSize} ${napkinBottom}
    L ${napkinX + napkinRadius} ${napkinBottom}
    Q ${napkinX} ${napkinBottom} ${napkinX} ${napkinBottom - napkinRadius}
    L ${napkinX} ${napkinY + napkinRadius}
    Q ${napkinX} ${napkinY} ${napkinX + napkinRadius} ${napkinY}
    Z
  `;

  // Corner fold triangle reveal (darker cream behind the fold)
  // The fold: crease line from (napkinRight - foldSize, napkinBottom) to (napkinRight, napkinBottom - foldSize)
  // Background peek triangle
  const foldRevealPath = `
    M ${napkinRight - foldSize} ${napkinBottom}
    L ${napkinRight} ${napkinBottom - foldSize}
    L ${napkinRight} ${napkinBottom}
    Z
  `;

  // Shadow triangle on top of fold to simulate paper curling over
  const foldShadowPath = `
    M ${napkinRight - foldSize} ${napkinBottom}
    L ${napkinRight} ${napkinBottom - foldSize}
    L ${napkinRight - foldSize + 12} ${napkinBottom - 12}
    Z
  `;

  // Waveform: centered on the napkin
  // Center: (512, 512), width spans ~480px, bars are vertical lines
  const waveformCenterX = 512;
  const waveformCenterY = 512;
  const strokeW = 7;
  const barGap = 16;

  // Waveform bar heights — realistic audio waveform shape, tapers at ends
  const barHeights = [
    14, 22, 34, 48, 56, 70, 82, 96, 108, 118,
    124, 120, 112, 104, 96, 104, 112, 120, 124, 118,
    108, 96, 82, 70, 56, 48, 34, 22, 14
  ];

  const totalBars = barHeights.length;
  const totalWidth = (totalBars - 1) * barGap;
  const startX = waveformCenterX - totalWidth / 2;

  const waveformBars = barHeights.map((h, i) => {
    const x = startX + i * barGap;
    return (
      <line
        key={i}
        x1={x}
        y1={waveformCenterY - h / 2}
        x2={x}
        y2={waveformCenterY + h / 2}
        stroke="#2C2C2C"
        strokeWidth={strokeW}
        strokeLinecap="round"
      />
    );
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#FFF8F0",
      }}
    >
      <svg
        width={1024}
        height={1024}
        viewBox="0 0 1024 1024"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          {/* Drop shadow filter for napkin */}
          <filter id="napkinShadow" x="-5%" y="-5%" width="115%" height="115%">
            <feDropShadow
              dx="0"
              dy="4"
              stdDeviation="12"
              floodColor="#C8B8A0"
              floodOpacity="0.35"
            />
          </filter>
        </defs>

        {/* Napkin body */}
        <path
          d={napkinPath}
          fill="#FFFDF8"
          filter="url(#napkinShadow)"
        />

        {/* Corner fold — darker cream reveal (background showing through) */}
        <path
          d={foldRevealPath}
          fill="#F5EDE0"
        />

        {/* Corner fold shadow — paper folding over */}
        <path
          d={foldShadowPath}
          fill="#D9C9B4"
          opacity="0.6"
        />

        {/* Subtle crease line */}
        <line
          x1={napkinRight - foldSize}
          y1={napkinBottom}
          x2={napkinRight}
          y2={napkinBottom - foldSize}
          stroke="#C8B8A0"
          strokeWidth="1.5"
          opacity="0.7"
        />

        {/* Waveform bars */}
        {waveformBars}
      </svg>
    </AbsoluteFill>
  );
};
