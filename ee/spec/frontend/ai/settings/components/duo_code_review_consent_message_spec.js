import { shallowMount } from '@vue/test-utils';
import DuoCodeReviewConsentMessage from 'ee/ai/settings/components/duo_code_review_consent_message.vue';

describe('DuoCodeReviewConsentMessage', () => {
  let wrapper;

  const defaultProvide = {
    duoEnterpriseActive: true,
  };

  const createWrapper = (props = {}, provide = {}) => {
    return shallowMount(DuoCodeReviewConsentMessage, {
      propsData: {
        codeReviewFlowSelected: false,
        codeReviewFlowConsentGiven: false,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findConsentWarning = () => wrapper.find('[data-testid="code-review-flow-consent-warning"]');
  const findConsentInfo = () => wrapper.find('[data-testid="code-review-flow-consent-info"]');

  describe('when consent is not required', () => {
    describe('when duoEnterpriseActive is false', () => {
      beforeEach(() => {
        wrapper = createWrapper({ codeReviewFlowSelected: true }, { duoEnterpriseActive: false });
      });

      it('does not show the warning', () => {
        expect(findConsentWarning().exists()).toBe(false);
      });

      it('does not show the info', () => {
        expect(findConsentInfo().exists()).toBe(false);
      });
    });
  });

  describe('when code review flow is not selected', () => {
    beforeEach(() => {
      wrapper = createWrapper({ codeReviewFlowSelected: false });
    });

    it('does not show the warning', () => {
      expect(findConsentWarning().exists()).toBe(false);
    });

    it('does not show the info', () => {
      expect(findConsentInfo().exists()).toBe(false);
    });
  });

  describe('when consent is required and code review flow is selected', () => {
    describe('when consent has not been given', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          codeReviewFlowSelected: true,
          codeReviewFlowConsentGiven: false,
        });
      });

      it('shows the consent warning alert', () => {
        expect(findConsentWarning().exists()).toBe(true);
      });

      it('renders the warning as a GlAlert with warning variant', () => {
        expect(findConsentWarning().attributes('variant')).toBe('warning');
      });

      it('does not show the consent info alert', () => {
        expect(findConsentInfo().exists()).toBe(false);
      });
    });

    describe('when consent has been given', () => {
      beforeEach(() => {
        wrapper = createWrapper({ codeReviewFlowSelected: true, codeReviewFlowConsentGiven: true });
      });

      it('does not show the consent warning alert', () => {
        expect(findConsentWarning().exists()).toBe(false);
      });

      it('shows the consent info alert', () => {
        expect(findConsentInfo().exists()).toBe(true);
      });

      it('renders the info as a GlAlert with info variant', () => {
        expect(findConsentInfo().attributes('variant')).toBe('info');
      });
    });
  });
});
