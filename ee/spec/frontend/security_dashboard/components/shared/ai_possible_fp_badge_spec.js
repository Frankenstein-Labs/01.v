import { GlBadge, GlPopover, GlProgressBar } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { CONFIDENCE_SCORES } from 'ee/vulnerabilities/constants';
import AiPossibleFpBadge from 'ee/security_dashboard/components/shared/ai_possible_fp_badge.vue';

describe('AiPossibleFpBadge', () => {
  let wrapper;

  const defaultVulnerability = {
    id: 'gid://gitlab/Vulnerabilities::Finding/123',
    title: 'Test Vulnerability',
    latestFlag: {
      confidenceScore: 0.61,
      status: 'DETECTED_AS_FP',
      origin: 'ai_sast_fp_detection',
      description: 'This is likely a false positive because...',
    },
  };

  const createComponent = (props = {}, options = {}) => {
    wrapper = shallowMountExtended(AiPossibleFpBadge, {
      propsData: {
        vulnerability: {
          ...defaultVulnerability,
          ...props.vulnerability,
        },
        ...props,
      },
      stubs: {
        GlPopover,
      },
      ...options,
    });
    return wrapper;
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findBadgeText = () => wrapper.findByTestId('ai-fix-in-progress-b');
  const findProgressBar = () => wrapper.findComponent(GlProgressBar);

  describe('when confidence score is between minimal and likely threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: 0.61,
          },
        },
      });
    });

    it('renders the badge with warning variant', () => {
      expect(findBadge().props('variant')).toBe('warning');
    });

    it('renders "Possible FP" text', () => {
      expect(findBadgeText().text()).toBe('Possible FP');
    });

    it('renders the confidence score correctly', () => {
      expect(findProgressBar().props('value')).toBe(61);
      expect(findProgressBar().props('variant')).toBe('warning');
      expect(wrapper.text()).toContain('61%');
    });
  });

  describe('when confidence score is above the likely threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: CONFIDENCE_SCORES.LIKELY_FALSE_POSITIVE + 0.1,
          },
        },
      });
    });

    it('renders the badge with success variant', () => {
      expect(findBadge().props('variant')).toBe('success');
    });

    it('renders "Likely FP" text', () => {
      expect(findBadgeText().text()).toBe('Likely FP');
    });

    it('renders the progress bar with success variant', () => {
      expect(findProgressBar().props('variant')).toBe('success');
      expect(findProgressBar().props('value')).toBe(90);
    });
  });

  describe('when confidence score is below the minimal threshold', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: CONFIDENCE_SCORES.MINIMAL - 0.1,
          },
        },
      });
    });

    it('renders the badge with neutral variant', () => {
      expect(findBadge().props('variant')).toBe('neutral');
    });

    it('renders "Not an FP" text', () => {
      expect(findBadgeText().text()).toBe('Not an FP');
    });

    it('renders the progress bar with primary variant', () => {
      expect(findProgressBar().props('variant')).toBe('primary');
    });

    it('renders the "Not a false positive" message', () => {
      expect(wrapper.text()).toContain('FP scanning found that this vulnerability is');
      expect(wrapper.text()).toContain('NOT a false positive');
    });
  });

  describe('when confidence score indicates possible or likely false positive', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('renders the "For more information" message', () => {
      expect(wrapper.text()).toContain('For more information, view vulnerability details.');
    });
  });

  describe('when flag status is pending (NOT_STARTED)', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: 0,
            status: 'NOT_STARTED',
            origin: 'ai_sast_fp_detection',
          },
        },
      });
    });

    it('renders the badge with info variant', () => {
      expect(findBadge().props('variant')).toBe('info');
    });

    it('renders "FP scanning" text', () => {
      expect(findBadgeText().text()).toBe('FP scanning');
    });

    it('does not render the progress bar', () => {
      expect(findProgressBar().exists()).toBe(false);
    });
  });

  describe('when flag status is IN_PROGRESS', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: 0,
            status: 'IN_PROGRESS',
            origin: 'ai_sast_fp_detection',
          },
        },
      });
    });

    it('renders the badge with info variant', () => {
      expect(findBadge().props('variant')).toBe('info');
    });

    it('renders "FP scanning" text', () => {
      expect(findBadgeText().text()).toBe('FP scanning');
    });
  });

  describe('when flag status is FAILED', () => {
    beforeEach(() => {
      wrapper = createComponent({
        vulnerability: {
          latestFlag: {
            confidenceScore: 0,
            status: 'FAILED',
            origin: 'ai_sast_fp_detection',
          },
        },
      });
    });

    it('renders the badge with danger variant', () => {
      expect(findBadge().props('variant')).toBe('danger');
    });

    it('renders "FP scan failed" text', () => {
      expect(findBadgeText().text()).toBe('FP scan failed');
    });

    it('does not render the progress bar', () => {
      expect(findProgressBar().exists()).toBe(false);
    });
  });
});
