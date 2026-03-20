import React from "react";
import { Composition } from "remotion";
import { JottrIcon } from "./JottrIcon";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="JottrIcon"
      component={JottrIcon}
      durationInFrames={1}
      fps={1}
      width={1024}
      height={1024}
    />
  );
};
