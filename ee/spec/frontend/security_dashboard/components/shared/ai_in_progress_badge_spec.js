import { GlBadge, GlIcon, GlAnimatedLoaderIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiInProgressBadge from 'ee/security_dashboard/components/shared/ai_in_progress_badge.vue';
import {
  WORKFLOW_NAMES,
  AI_WORKFLOW_I18N,
} from 'ee/security_dashboard/components/shared/vulnerability_report/constants';

describe('AiInProgressBadge', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(AiInProgressBadge, {
      propsData: {
        workflowName: WORKFLOW_NAMES.RESOLVE_SAST_VULNERABILITY,
        ...props,
      },
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);

  describe('common badge elements', () => {
    beforeEach(() => {
      createWrapper({ workflowName: WORKFLOW_NAMES.RESOLVE_SAST_VULNERABILITY });
    });

    it('renders a badge with the correct variant', () => {
      expect(findBadge().props()).toMatchObject({
        variant: 'info',
      });
    });

    it('renders the duo icon', () => {
      expect(wrapper.findComponent(GlIcon).props()).toMatchObject({
        name: 'tanuki-ai',
      });
    });

    it('renders the animated loader icon', () => {
      expect(wrapper.findComponent(GlAnimatedLoaderIcon).exists()).toBe(true);
    });

    it('renders accessible tooltip text with screen reader class', () => {
      const tooltip = wrapper.findByTestId('ai-fix-in-progress-badge-tooltip');
      expect(tooltip.classes()).toContain('gl-sr-only');
    });
  });

  describe('RESOLVE_SAST_VULNERABILITY workflow content', () => {
    beforeEach(() => {
      createWrapper({ workflowName: WORKFLOW_NAMES.RESOLVE_SAST_VULNERABILITY });
    });

    it('renders the correct badge text', () => {
      expect(wrapper.findByTestId('ai-fix-in-progress-badge-text').text()).toBe(
        AI_WORKFLOW_I18N[WORKFLOW_NAMES.RESOLVE_SAST_VULNERABILITY].badgeText,
      );
    });

    it('renders the correct tooltip message', () => {
      expect(findBadge().attributes('title')).toBe(
        AI_WORKFLOW_I18N[WORKFLOW_NAMES.RESOLVE_SAST_VULNERABILITY].tooltipText,
      );
    });

    it('renders the correct accessible tooltip text', () => {
      const tooltip = wrapper.findByTestId('ai-fix-in-progress-badge-tooltip');
      expect(tooltip.text()).toBe(
        AI_WORKFLOW_I18N[WORKFLOW_NAMES.RESOLVE_SAST_VULNERABILITY].tooltipText,
      );
    });
  });

  describe('SAST_FP_DETECTION workflow content', () => {
    beforeEach(() => {
      createWrapper({ workflowName: WORKFLOW_NAMES.SAST_FP_DETECTION });
    });

    it('renders the correct badge text', () => {
      expect(wrapper.findByTestId('ai-fix-in-progress-badge-text').text()).toBe(
        AI_WORKFLOW_I18N[WORKFLOW_NAMES.SAST_FP_DETECTION].badgeText,
      );
    });

    it('renders the correct tooltip message', () => {
      expect(findBadge().attributes('title')).toBe(
        AI_WORKFLOW_I18N[WORKFLOW_NAMES.SAST_FP_DETECTION].tooltipText,
      );
    });

    it('renders the correct accessible tooltip text', () => {
      const tooltip = wrapper.findByTestId('ai-fix-in-progress-badge-tooltip');
      expect(tooltip.text()).toBe(AI_WORKFLOW_I18N[WORKFLOW_NAMES.SAST_FP_DETECTION].tooltipText);
    });
  });
});
