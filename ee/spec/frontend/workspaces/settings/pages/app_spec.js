import { shallowMount } from '@vue/test-utils';
import AgentMapping from 'ee_component/workspaces/agent_mapping/components/agent_mapping.vue';
import App from 'ee_component/workspaces/settings/pages/app.vue';

describe('workspaces/settings/pages/app.vue', () => {
  let wrapper;

  const buildWrapper = () => {
    wrapper = shallowMount(App);
  };

  it('renders AgentMapping component', () => {
    buildWrapper();

    expect(wrapper.findComponent(AgentMapping).exists()).toBe(true);
  });
});
