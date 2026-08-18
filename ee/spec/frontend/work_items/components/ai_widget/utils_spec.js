import { AGENT_STEP_PILL_VARIANTS } from 'ee/work_items/components/ai_widget/constants';
import { getVariantColor } from 'ee/work_items/components/ai_widget/utils';

describe('agent_plan utils', () => {
  describe('getVariantColor', () => {
    it.each(Object.entries(AGENT_STEP_PILL_VARIANTS))(
      'returns the "%s" color for the "%s" variant',
      (variant, expectedColor) => {
        expect(getVariantColor(variant)).toBe(expectedColor);
      },
    );

    describe('when the variant is unknown', () => {
      it('falls back to the neutral color', () => {
        expect(getVariantColor('unknown')).toBe(AGENT_STEP_PILL_VARIANTS.neutral);
      });
    });
  });
});
