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
import { getColors } from 'ee/compliance_dashboard/components/dashboard/utils/chart';
import { GL_DARK, GL_LIGHT } from '~/constants';

describe('chart utility functions', () => {
  describe('getColors', () => {
    it('returns expected structure', () => {
      expect(Object.keys(getColors(GL_LIGHT)).sort()).toStrictEqual(
        ['textColor', 'blueDataColor', 'orangeDataColor', 'magentaDataColor', 'ticksColor'].sort(),
      );
    });

    it('generates correct colors for light color scheme', () => {
      const { textColor, blueDataColor, orangeDataColor, magentaDataColor, ticksColor } =
        getColors(GL_LIGHT);
      expect(textColor).toEqual(GL_TEXT_COLOR_DEFAULT);
      expect(blueDataColor).toEqual(DATA_VIZ_BLUE_500);
      expect(orangeDataColor).toEqual(DATA_VIZ_ORANGE_400);
      expect(magentaDataColor).toEqual(DATA_VIZ_MAGENTA_500);
      expect(ticksColor).toEqual(GRAY_900);
    });

    it('generates correct colors for dark color scheme', () => {
      const { textColor, blueDataColor, orangeDataColor, magentaDataColor, ticksColor } =
        getColors(GL_DARK);
      expect(textColor).toEqual(GL_TEXT_COLOR_DEFAULT_DARK);
      expect(blueDataColor).toEqual(DATA_VIZ_BLUE_500);
      expect(orangeDataColor).toEqual(DATA_VIZ_ORANGE_400);
      expect(magentaDataColor).toEqual(DATA_VIZ_MAGENTA_500);
      expect(ticksColor).toEqual(GRAY_900_DARK);
    });

    it('adopts to color scheme change', () => {
      expect(getColors(GL_LIGHT)).not.toEqual(getColors(GL_DARK));
    });
  });
});
