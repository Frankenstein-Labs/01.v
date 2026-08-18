import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NoNamespaceEmptyState from 'ee/ai/duo_agentic_chat/components/no_namespace_empty_state.vue';
import TanukiAiIcon from 'ee/ai/shared/widgets/tanuki_ai_icon.vue';

describe('NoNamespaceEmptyState', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(NoNamespaceEmptyState, {
      propsData: {
        preferencesPath: '/-/profile/preferences',
        isClassicAvailable: true,
        ...props,
      },
    });
  };

  const findSelectNamespaceButton = () => wrapper.findByTestId('go-to-preferences-button');
  const findReturnToClassicButton = () =>
    wrapper.findAllComponents(GlButton).wrappers.find((w) => !w.attributes('data-testid'));
  const findContainer = () => wrapper.findByTestId('no-namespace-empty-state');
  const findImage = () => wrapper.findComponent(TanukiAiIcon);
  const findHeading = () => wrapper.find('h2');
  const findParagraph = () => wrapper.find('p');

  describe('rendering', () => {
    it('renders correctly', () => {
      createComponent({ isClassicAvailable: true });

      expect(findContainer().exists()).toBe(true);
      expect(findImage().exists()).toBe(true);
      expect(findHeading().text()).toBe('GitLab Duo Agentic Chat is unavailable');
      expect(findParagraph().text()).toBe(
        'To use Chat, select a default namespace in your user profile preferences. Alternatively, turn off the Agentic toggle to return to non-agentic Chat.',
      );
      expect(findSelectNamespaceButton().exists()).toBe(true);
      expect(findReturnToClassicButton().exists()).toBe(true);
    });

    it('does not mention the Agentic toggle when isClassicAvailable is false', () => {
      createComponent({ isClassicAvailable: false });

      expect(findParagraph().text()).toBe(
        'To use Chat, select a default namespace in your user profile preferences.',
      );
    });
  });

  describe('conditional rendering', () => {
    it('does not render "Select default namespace" button when preferencesPath is empty', () => {
      createComponent({ preferencesPath: '' });

      expect(findSelectNamespaceButton().exists()).toBe(false);
    });

    it('renders "Select default namespace" button when preferencesPath is provided', () => {
      createComponent({ preferencesPath: '/-/profile/preferences' });

      expect(findSelectNamespaceButton().exists()).toBe(true);
    });

    it('does not render "Return to Classic Chat" button when isClassicAvailable is false', () => {
      createComponent({ isClassicAvailable: false });

      expect(findReturnToClassicButton()).toBeUndefined();
    });

    it('renders "Return to Classic Chat" button when isClassicAvailable is true', () => {
      createComponent({ isClassicAvailable: true });

      expect(findReturnToClassicButton()).toBeDefined();
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits "return-to-classic" when "Return to Classic Chat" button is clicked', () => {
      findReturnToClassicButton().vm.$emit('click');

      expect(wrapper.emitted('return-to-classic')).toHaveLength(1);
    });
  });
});
