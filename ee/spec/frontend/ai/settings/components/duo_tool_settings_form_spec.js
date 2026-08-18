import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import DuoToolSettingsForm from 'ee/ai/settings/components/duo_tool_settings_form.vue';

describe('DuoWorkflowSettingsForm', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(DuoToolSettingsForm, {
      propsData: {
        isMcpEnabled: false,
        showMcp: true,
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlFormCheckbox: stubComponent(GlFormCheckbox, {
          template: `<div>
                      <slot></slot>
                      <slot name="help"></slot>
                    </div>`,
        }),
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  const findGlFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findToolsHeader = () => wrapper.find('[data-testid="tools-subsection-header"]');
  const findToolsDescription = () => wrapper.find('[data-testid="tools-subsection-description"]');

  describe('section header and description', () => {
    it('renders the flows section header', () => {
      expect(findToolsHeader().text()).toBe('Tools');
    });

    it('renders the flows section description', () => {
      expect(findToolsDescription().text()).toBe(
        'Interact directly with GitLab and perform common GitLab operations.',
      );
    });
  });

  describe('MCP Section', () => {
    it('renders the MCP section title correctly', () => {
      expect(findGlFormGroup().exists()).toBe(true);
      expect(wrapper.text()).toContain('External MCP tools');
    });

    it('renders the checkbox with correct label', () => {
      expect(findFormCheckbox().exists()).toBe(true);
      expect(findFormCheckbox().text()).toContain('Allow external MCP tools');
    });

    it('renders the help text correctly', () => {
      expect(findFormCheckbox().text()).toContain('Allow the IDE to access external MCP tools.');
    });

    it.each([[false], [true]])(
      'sets checkbox with the isMcpEnabled prop %p',
      async (isMcpEnabled) => {
        wrapper = createComponent({ isMcpEnabled });

        await nextTick();

        expect(findFormCheckbox().props('checked')).toBe(isMcpEnabled);
      },
    );

    describe('when checkbox is clicked', () => {
      beforeEach(async () => {
        findFormCheckbox().vm.$emit('change', true);
        await nextTick();
      });

      it('emits the `mcp-change` event with the correct payload', () => {
        expect(wrapper.emitted('mcp-change')[0]).toEqual([true]);
      });
    });

    it('renders checkbox with correct data-testid attribute', () => {
      expect(findFormCheckbox().attributes('data-testid')).toBe(
        'enable-duo-workflow-mcp-enabled-checkbox',
      );
    });

    it('renders checkbox with correct name attribute', () => {
      expect(findFormCheckbox().props('name')).toBe(
        'namespace[ai_settings_attributes][duo_workflow_mcp_enabled]',
      );
    });

    it('hides MCP section when showMcp is false', () => {
      wrapper = createComponent({ showMcp: false });
      expect(findFormCheckbox().exists()).toBe(false);
    });
  });
});
