import {
  GL_TEXT_COLOR_DEFAULT,
  DATA_VIZ_BLUE_500,
  DATA_VIZ_ORANGE_400,
  DATA_VIZ_MAGENTA_500,
  GRAY_900,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import {
  GL_TEXT_COLOR_DEFAULT as GL_TEXT_COLOR_DEFAULT_DARK,
  GRAY_900 as GRAY_900_DARK,
} from '@gitlab/ui/src/tokens/build/js/tokens.dark';

import { GL_DARK } from '~/constants';

export function getColors(colorScheme) {
  const isDark = colorScheme === GL_DARK;

  return {
    textColor: isDark ? GL_TEXT_COLOR_DEFAULT_DARK : GL_TEXT_COLOR_DEFAULT,
    blueDataColor: DATA_VIZ_BLUE_500,
    orangeDataColor: DATA_VIZ_ORANGE_400,
    magentaDataColor: DATA_VIZ_MAGENTA_500,
    ticksColor: isDark ? GRAY_900_DARK : GRAY_900,
  };
}
