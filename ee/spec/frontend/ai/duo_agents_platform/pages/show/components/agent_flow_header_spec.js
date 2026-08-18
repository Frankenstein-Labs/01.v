import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowHeader from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_header.vue';

describe('AgentFlowHeader', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AgentFlowHeader, {
      propsData: {
        isLoading: false,
        title: '',
        agentFlowDefinition: 'Software development',
        ...props,
      },
      mocks: {
        $route: {
          params: { id: '123' },
        },
      },
    });
  };

  const findHeading = () => wrapper.find('h1');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('renders the loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render the heading or prompt text', () => {
      expect(findHeading().exists()).toBe(false);
    });
  });

  describe('when loaded', () => {
    describe('with a custom title', () => {
      beforeEach(() => {
        createComponent({ title: 'My custom title' });
      });

      it('renders the custom title', () => {
        expect(findHeading().text()).toBe('My custom title');
      });
    });

    describe('with workflow definition and no custom title', () => {
      beforeEach(() => {
        createComponent({ title: '' });
      });

      it('renders the workflow header title', () => {
        expect(findHeading().text()).toBe('Software development #123');
      });
    });

    describe('without a workflow definition or custom title', () => {
      beforeEach(() => {
        createComponent({ title: '', agentFlowDefinition: '' });
      });

      it('renders the default workflow header title', () => {
        expect(findHeading().text()).toBe('Agent session #123');
      });
    });
  });
});
