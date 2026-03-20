import {Composition} from 'remotion';
import {JottrDemo} from './JottrDemo';

export const RemotionRoot = () => {
  return (
    <Composition
      id="JottrDemo"
      component={JottrDemo}
      durationInFrames={300}
      fps={30}
      width={1200}
      height={630}
    />
  );
};
