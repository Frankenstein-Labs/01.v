import { shallowMount } from '@vue/test-utils';
import { assertProps } from 'helpers/assert_props';
import ConfidenceBar from 'ee/work_items/components/ai_widget/confidence_bar.vue';
import { PLAN_CONFIDENCE_LEVELS } from 'ee/work_items/components/ai_widget/constants';

describe('ConfidenceBar', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ConfidenceBar, {
      propsData: {
        confidenceLevel: PLAN_CONFIDENCE_LEVELS.HIGH,
        ...props,
      },
    });
  };

  const findTrack = () => wrapper.find('span');
  const findFill = () => wrapper.find('span > span');

  describe('confidenceLevel prop validator', () => {
    it.each(Object.values(PLAN_CONFIDENCE_LEVELS))('accepts the "$value" level', (level) => {
      expect(() => assertProps(ConfidenceBar, { confidenceLevel: level })).not.toThrow();
    });

    it('rejects an unknown level', () => {
      expect(() => assertProps(ConfidenceBar, { confidenceLevel: { value: 'UNKNOWN' } })).toThrow();
    });
  });

  describe.each`
    level                            | width
    ${PLAN_CONFIDENCE_LEVELS.LOW}    | ${'33.33333333333333%'}
    ${PLAN_CONFIDENCE_LEVELS.MEDIUM} | ${'66.66666666666666%'}
    ${PLAN_CONFIDENCE_LEVELS.HIGH}   | ${'100%'}
  `('when confidence level is $value', ({ level, width }) => {
    beforeEach(() => {
      createComponent({ confidenceLevel: level });
    });

    it(`fills the track to ${width}`, () => {
      expect(findFill().element.style.width).toBe(width);
    });
  });

  describe('when an ariaLabel is provided', () => {
    beforeEach(() => {
      createComponent({ ariaLabel: 'Confidence: HIGH' });
    });

    it('renders it on the track element', () => {
      expect(findTrack().attributes('aria-label')).toBe('Confidence: HIGH');
    });
  });
});
