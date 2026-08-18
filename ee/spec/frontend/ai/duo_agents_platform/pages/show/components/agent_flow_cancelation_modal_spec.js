import { GlButton, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowCancelationModal from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_cancelation_modal.vue';

describe('AgentFlowCancelationModal', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AgentFlowCancelationModal, {
      propsData: {
        visible: false,
        loading: false,
        ...props,
      },
      stubs: {
        GlModal,
        GlButton,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findCancelButton = () =>
    wrapper.findComponent('[data-testid="cancel-session-modal-cancel"]');
  const findConfirmButton = () =>
    wrapper.findComponent('[data-testid="cancel-session-modal-confirm"]');

  describe('when component has rendered', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal with correct props', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props('modalId')).toBe('cancel-session-confirmation-modal');
      expect(findModal().props('title')).toBe('Cancel session?');
      expect(findModal().props('size')).toBe('sm');
    });

    it('renders the confirmation message', () => {
      expect(wrapper.text()).toContain(
        'Are you sure you want to cancel this session? This action cannot be undone.',
      );
    });

    it('renders cancel button with correct text', () => {
      expect(findCancelButton().exists()).toBe(true);
      expect(findCancelButton().text()).toBe('Cancel');
    });

    it('renders confirm button with correct text and variant', () => {
      const confirmButton = findConfirmButton();

      expect(confirmButton.exists()).toBe(true);
      expect(confirmButton.text()).toBe('Cancel session');
      expect(confirmButton.props()).toMatchObject({
        variant: 'danger',
      });
    });
  });

  describe('visibility', () => {
    it.each`
      visible  | expected
      ${true}  | ${true}
      ${false} | ${false}
    `('passes visible=$visible prop to modal', ({ visible, expected }) => {
      createComponent({ visible });

      expect(findModal().props('visible')).toBe(expected);
    });
  });

  describe('loading state', () => {
    it.each`
      loading  | expected
      ${true}  | ${true}
      ${false} | ${false}
    `('passes loading=$loading to confirm button', ({ loading, expected }) => {
      createComponent({ loading });

      expect(findConfirmButton().props('loading')).toBe(expected);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent({ visible: true });
    });

    it.each`
      action               | finder               | event      | emittedEvent
      ${'modal hidden'}    | ${() => findModal()} | ${'hide'}  | ${'hide'}
      ${'cancel clicked'}  | ${findCancelButton}  | ${'click'} | ${'hide'}
      ${'confirm clicked'} | ${findConfirmButton} | ${'click'} | ${'confirm'}
    `('emits $emittedEvent when $action', async ({ finder, event, emittedEvent }) => {
      await finder().vm.$emit(event);

      expect(wrapper.emitted(emittedEvent)).toHaveLength(1);
    });
  });
});
