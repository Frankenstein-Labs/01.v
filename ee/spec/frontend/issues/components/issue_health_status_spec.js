import { GlBadge, GlIcon } from '@gitlab/ui';
import IssueHealthStatus from 'ee/issues/components/issue_health_status.vue';
import {
  healthStatusColorMap,
  healthStatusIconMap,
  healthStatusTextMap,
  healthStatusVariantMap,
} from 'ee/sidebar/constants';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('IssueHealthStatus', () => {
  const healthStatus = 'onTrack';
  let wrapper;

  const createComponent = ({
    displayAsText = false,
    textSize = 'base',
    disableTooltip = false,
  } = {}) =>
    shallowMountExtended(IssueHealthStatus, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        healthStatus,
        displayAsText,
        textSize,
        disableTooltip,
      },
    });

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findStatusText = () => wrapper.findByTestId('status-text');
  const findButton = () => wrapper.find('button');

  describe('badge mode', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders a badge', () => {
      expect(findBadge().exists()).toBe(true);
    });

    it('renders health status text', () => {
      const expectedValue = healthStatusTextMap[healthStatus];

      expect(findBadge().text()).toBe(expectedValue);
    });

    it('applies correct health status class', () => {
      expect(findBadge().attributes('variant')).toBe(healthStatusVariantMap[healthStatus]);
    });

    it('contains health status tooltip', () => {
      expect(getBinding(findButton().element, 'gl-tooltip')).not.toBeUndefined();
      expect(findButton().attributes('title')).toBe('Health status');
    });
  });

  describe('text mode', () => {
    describe('with default props', () => {
      beforeEach(() => {
        wrapper = createComponent({ displayAsText: true });
      });

      it('renders text and an icon', () => {
        expect(findIcon().exists()).toBe(true);
        expect(findStatusText().exists()).toBe(true);
      });

      it('renders health status text', () => {
        const expectedValue = healthStatusTextMap[healthStatus];

        expect(findStatusText().text()).toBe(expectedValue);
      });

      it('renders correct icon', () => {
        expect(findIcon().attributes('name')).toBe(healthStatusIconMap[healthStatus]);
      });

      it('applies correct color', () => {
        expect(findStatusText().classes(healthStatusColorMap[healthStatus])).toBe(true);
      });

      it('contains health status tooltip', () => {
        expect(getBinding(findButton().element, 'gl-tooltip')).not.toBeUndefined();
        expect(findButton().attributes('title')).toBe('Health status');
      });
    });

    describe('when textSize prop is set', () => {
      it.each(['base', 'sm'])('When the textSize is %s', (size) => {
        wrapper = createComponent({ displayAsText: true, textSize: size });

        expect(findStatusText().classes(`gl-text-${size}`)).toBe(true);
      });
    });

    describe.each([true, false])('when disableTooltip prop is %s', (tooltipDisabled) => {
      beforeEach(() => {
        wrapper = createComponent({ displayAsText: true, disableTooltip: tooltipDisabled });
      });

      it('enables the tooltip correctly', () => {
        const { value } = getBinding(findButton().element, 'gl-tooltip');

        expect(value.disabled).toBe(tooltipDisabled);
      });

      it('sets the correct cursor class', () => {
        expect(findStatusText().classes('gl-cursor-help')).toBe(!tooltipDisabled);
      });
    });
  });
});
