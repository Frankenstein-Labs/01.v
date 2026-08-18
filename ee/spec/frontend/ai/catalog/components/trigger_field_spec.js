import { shallowMount } from '@vue/test-utils';
import { GlLink, GlSprintf } from '@gitlab/ui';
import TriggerField from 'ee/ai/catalog/components/trigger_field.vue';
import FlowTriggerEventTokens from 'ee/ai/duo_agents_platform/components/common/flow_trigger_event_tokens.vue';
import {
  FLOW_TRIGGERS_EDIT_ROUTE,
  FLOW_TRIGGERS_NEW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import { mockFlow, mockFlowConfigurationForProject } from '../mock_data';

describe('TriggerFieldSpec', () => {
  let wrapper;

  const defaultProps = {
    item: mockFlow,
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMount(TriggerField, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findEditLink = () => wrapper.findComponent(GlLink);
  const findAllLinks = () => wrapper.findAllComponents(GlLink);
  const findEventTokens = () => wrapper.findComponent(FlowTriggerEventTokens);

  describe('when flowTrigger is empty', () => {
    describe('when user can manage triggers', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForProject: {
                ...mockFlowConfigurationForProject,
                flowTrigger: null,
              },
            },
          },
          provide: {
            glAbilities: { manageAiFlowTriggers: true },
          },
        });
      });

      it('renders "Add a trigger" message with link', () => {
        const link = wrapper.findComponent(GlLink);

        expect(wrapper.text()).toBe(
          'No triggers configured. Add a trigger to make this flow available.',
        );
        expect(link.props('to')).toEqual({ name: FLOW_TRIGGERS_NEW_ROUTE });
      });

      it('does not render the trigger event tokens', () => {
        expect(findEventTokens().exists()).toBe(false);
      });
    });

    describe('when user cannot manage triggers', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForProject: {
                ...mockFlowConfigurationForProject,
                flowTrigger: null,
              },
            },
          },
          provide: {
            glAbilities: { manageAiFlowTriggers: false },
          },
        });
      });

      it('renders "No triggers configured" without a link', () => {
        expect(wrapper.text()).toBe('No triggers configured.');
        expect(findAllLinks()).toHaveLength(0);
      });
    });
  });

  describe('when flowTrigger exists', () => {
    describe('when user can manage triggers', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForProject: mockFlowConfigurationForProject,
            },
          },
          provide: {
            glAbilities: { manageAiFlowTriggers: true },
          },
        });
      });

      it('renders the trigger event tokens with the stored flow trigger', () => {
        expect(findEventTokens().props('flowTrigger')).toEqual(
          mockFlowConfigurationForProject.flowTrigger,
        );
      });

      it('renders trigger edit link', () => {
        const editLink = findEditLink();

        expect(editLink.text()).toBe('Edit');
        expect(editLink.props('to')).toEqual({
          name: FLOW_TRIGGERS_EDIT_ROUTE,
          params: { id: 73 },
        });
      });
    });

    describe('when user cannot manage triggers', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForProject: mockFlowConfigurationForProject,
            },
          },
          provide: {
            glAbilities: { manageAiFlowTriggers: false },
          },
        });
      });

      it('renders the trigger event tokens', () => {
        expect(findEventTokens().exists()).toBe(true);
      });

      it('does not render trigger edit link', () => {
        expect(findEditLink().exists()).toBe(false);
      });
    });
  });

  describe('when item is foundational', () => {
    beforeEach(() => {
      createComponent({
        props: {
          item: {
            ...mockFlow,
            foundational: true,
            configurationForProject: mockFlowConfigurationForProject,
          },
        },
        provide: {
          glAbilities: { manageAiFlowTriggers: true },
        },
      });
    });

    it('does not render trigger edit link', () => {
      expect(findEditLink().exists()).toBe(false);
    });
  });
});
