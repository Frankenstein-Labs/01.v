import { nextTick } from 'vue';
import { GlFormRadio, GlFormRadioGroup, GlTableLite, GlCollapsibleListbox } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoFoundationalAgentsSettings, {
  FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES,
} from 'ee/ai/settings/components/duo_foundational_agents_settings.vue';
import { mockAgentStatuses } from '../../mocks';

describe('DuoFoundationalAgentsSettings', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {}, mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(DuoFoundationalAgentsSettings, {
      propsData: {
        foundationalAgentsEnabled: true,
        agentStatuses: [],
        ...props,
      },
      provide: {
        showFoundationalAgentsPerAgentAvailability: true,
        ...provide,
      },
      stubs: {
        GlCollapsibleListbox,
      },
    });
  };

  const findEnabledRadio = () => wrapper.findAllComponents(GlFormRadio).at(0);
  const findDisabledRadio = () => wrapper.findAllComponents(GlFormRadio).at(1);
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findAgentsTable = () => wrapper.findComponent(GlTableLite);
  const findAgentDropdowns = () => wrapper.findAllComponents(GlCollapsibleListbox);
  const findAgentsHeader = () => wrapper.find('[data-testid="agents-subsection-header"]');
  const findAgentsDescription = () => wrapper.find('[data-testid="agents-subsection-description"]');

  beforeEach(() => {
    createComponent();
  });

  describe('section header and description', () => {
    it('renders the agents section header', () => {
      expect(findAgentsHeader().text()).toBe('Agents');
    });
    it('renders the agents section description', () => {
      expect(findAgentsDescription().text()).toBe(
        'Accomplish specific tasks and get answers to complex questions.',
      );
    });
  });

  describe('radio button labels', () => {
    describe('when showFoundationalAgentsPerAgentAvailability is true', () => {
      beforeEach(() => {
        createComponent({ mountFn: mountExtended });
      });

      it('shows "On" and "Off" labels', () => {
        expect(findEnabledRadio().text()).toContain('On');
        expect(findDisabledRadio().text()).toContain('Off');
      });

      it('does not show help text', () => {
        expect(findEnabledRadio().text()).not.toContain(
          'Foundational agents are available for projects in this group.',
        );
        expect(findDisabledRadio().text()).not.toContain('Foundational agents are not available.');
      });
    });

    describe('when showFoundationalAgentsPerAgentAvailability is false', () => {
      beforeEach(() => {
        createComponent({
          provide: { showFoundationalAgentsPerAgentAvailability: false },
          mountFn: mountExtended,
        });
      });

      it('shows "On by default" and "Off by default" labels', () => {
        expect(findEnabledRadio().text()).toContain('On');
        expect(findDisabledRadio().text()).toContain('Off');
      });

      it('shows help text', () => {
        expect(findEnabledRadio().text()).toContain(
          'Foundational agents are available for projects in this group.',
        );
        expect(findDisabledRadio().text()).toContain('Foundational agents are not available.');
      });
    });
  });

  it('selects enabled when enabled prop is true', () => {
    expect(findFormRadioGroup().attributes('checked')).toBe('true');
  });

  it('emits change event when enabled radio button is selected', async () => {
    findFormRadioGroup().vm.$emit('input', true);
    await nextTick();

    expect(wrapper.emitted('change')).toHaveLength(1);
    expect(wrapper.emitted('change')).toEqual([[true]]);
  });

  it('emits change event when disabled radio button is selected', async () => {
    findFormRadioGroup().vm.$emit('input', false);
    await nextTick();

    expect(wrapper.emitted('change')).toHaveLength(1);
    expect(wrapper.emitted('change')).toEqual([[false]]);
  });

  describe('agents table', () => {
    it('does not render the agents table when feature flag is disabled', () => {
      createComponent({
        provide: { showFoundationalAgentsPerAgentAvailability: false },
      });

      expect(findAgentsTable().exists()).toBe(false);
    });

    describe('when the feature flag is enabled', () => {
      it('does not render the agents table when agentStatuses is empty', () => {
        createComponent({
          props: { agentStatuses: [] },
        });
        expect(findAgentsTable().exists()).toBe(false);
      });

      describe('when agentStatuses has items', () => {
        beforeEach(() => {
          createComponent({
            props: { agentStatuses: mockAgentStatuses },
            mountFn: mountExtended,
          });
        });

        it('renders the agents table when feature flag is enabled', () => {
          expect(findAgentsTable().exists()).toBe(true);
          expect(findAgentsTable().props('items')).toEqual(mockAgentStatuses);
        });

        it('sets dropdown selected state based on agent enabled status', () => {
          expect(findAgentDropdowns().at(0).props('selected')).toBe('enabled');
          expect(findAgentDropdowns().at(1).props('selected')).toBe('disabled');
          expect(findAgentDropdowns().at(2).props('selected')).toBe('use_default');
        });

        it.each`
          defaultEnabledValue | expectedToggleText
          ${true}             | ${'Use default (On)'}
          ${false}            | ${'Use default (Off)'}
        `(
          'sets dropdown toggle text based on agent enabled status and default value',
          ({ defaultEnabledValue, expectedToggleText }) => {
            createComponent({
              props: {
                foundationalAgentsEnabled: defaultEnabledValue,
                agentStatuses: mockAgentStatuses,
              },
              mountFn: mountExtended,
            });

            expect(findAgentDropdowns().at(0).props('toggleText')).toBe('On');
            expect(findAgentDropdowns().at(1).props('toggleText')).toBe('Off');
            expect(findAgentDropdowns().at(2).props('toggleText')).toBe(expectedToggleText);
          },
        );

        it.each`
          optionValue                                         | expectedValue
          ${FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.disabled} | ${false}
          ${FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.enabled}  | ${true}
          ${FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.default}  | ${null}
        `(
          'emits agent-toggle event when the dropdown selection value is updated to: $optionValue',
          async ({ optionValue, expectedValue }) => {
            findAgentDropdowns().at(0).vm.$emit('select', optionValue);
            await nextTick();

            expect(wrapper.emitted('agent-toggle')[0][0]).toEqual([
              { reference: 'security-analyst', name: 'Security Analyst', enabled: expectedValue },
              { reference: 'code-reviewer', name: 'Code Reviewer', enabled: false },
              { reference: 'test-agent', name: 'Test Agent', enabled: null },
            ]);
          },
        );
      });
    });
  });
});
