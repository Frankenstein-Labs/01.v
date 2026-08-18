import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiToolManagementApp from 'ee/ai/governance/components/ai_tool_management/ai_tool_management_app.vue';
import AiToolRulesTable from 'ee/ai/governance/components/ai_tool_management/ai_tool_rules_table.vue';

describe('AiToolManagementApp', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(AiToolManagementApp);
  };

  it('renders the AiToolRulesTable component', () => {
    createComponent();

    expect(wrapper.findComponent(AiToolRulesTable).exists()).toBe(true);
  });
});
