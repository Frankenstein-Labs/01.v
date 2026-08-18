import { shallowMount } from '@vue/test-utils';
import AiLegalDisclaimer from 'ee/ai/duo_agents_platform/components/common/ai_legal_disclaimer.vue';

describe('AiLegalDisclaimer', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AiLegalDisclaimer, {
      propsData: props,
    });
  };

  const findDisclaimer = () => wrapper.find('[data-testid="ai-legal-disclaimer"]');

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('renders the disclaimer paragraph', () => {
      expect(findDisclaimer().exists()).toBe(true);
    });

    it('displays the correct disclaimer text', () => {
      expect(findDisclaimer().text()).toBe(
        'GitLab Duo can autonomously change code. Responses and changes can be inaccurate. Review carefully.',
      );
    });
  });
});
