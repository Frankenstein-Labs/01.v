import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import { FLOW_TRIGGERS_NEW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import FlowTriggersCta from 'ee/ai/duo_agents_platform/pages/flow_triggers/index/components/flow_triggers_cta.vue';

describe('FlowTriggersCta', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(FlowTriggersCta);
  };

  describe('Rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders button with correct route', () => {
      const button = wrapper.findComponent(GlButton);
      expect(button.props('to')).toEqual({ name: FLOW_TRIGGERS_NEW_ROUTE });
    });
  });
});
