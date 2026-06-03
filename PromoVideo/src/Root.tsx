import React from 'react';
import {Composition} from 'remotion';
import {OmniSiftPromo} from './OmniSiftPromo';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="OmniSiftPromo"
      component={OmniSiftPromo}
      width={1080}
      height={1920}
      fps={30}
      durationInFrames={900}
    />
  );
};
