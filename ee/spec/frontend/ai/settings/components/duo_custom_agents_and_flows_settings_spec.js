import { GlFormCheckbox, GlFormGroup } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoCustomAgentsAndFlowsSettings from 'ee/ai/settings/components/duo_custom_agents_and_flows_settings.vue';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';

describe('DuoCustomAgentsAndFlowsSettings', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {}, mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(DuoCustomAgentsAndFlowsSettings, {
      propsData: {
        customAgentsEnabled: true,
        customFlowsEnabled: true,
        externalAgentsEnabled: true,
        disabledCheckbox: false,
        ...props,
      },
      provide: {
        duoCustomAgentsCascadingSettings: null,
        duoCustomFlowsCascadingSettings: null,
        duoExternalAgentsCascadingSettings: null,
        ...provide,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findAllCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findAgentsCheckbox = () => findAllCheckboxes().at(0);
  const findExternalAgentsCheckbox = () => findAllCheckboxes().at(1);
  const findFlowsCheckbox = () => findAllCheckboxes().at(2);
  const findCustomAgentsCheckbox = () => wrapper.findByTestId('duo-custom-agents-checkbox');
  const findCustomFlowsCheckbox = () => wrapper.findByTestId('duo-custom-flows-checkbox');
  const findExternalAgentsCheckboxByTestId = () =>
    wrapper.findByTestId('duo-external-agents-checkbox');
  const findLockIcons = () => wrapper.findAllComponents(CascadingLockIcon);

  describe('rendering', () => {
    beforeEach(() => createComponent({ mountFn: mountExtended }));

    it('renders all three checkboxes', () => {
      expect(findCustomAgentsCheckbox().exists()).toBe(true);
      expect(findExternalAgentsCheckboxByTestId().exists()).toBe(true);
      expect(findCustomFlowsCheckbox().exists()).toBe(true);
    });

    it('renders the section title on the form group', () => {
      createComponent();
      expect(findFormGroup().attributes('label')).toBe('Custom and external agents and flows');
    });

    it('renders the custom agents label and help text', () => {
      const text = findAgentsCheckbox().text();
      expect(text).toContain('Allow custom agents');
      expect(text).toContain(
        'Users with the Maintainer or Owner role for a project can create new agents.',
      );
    });

    it('renders the external agents label and help text', () => {
      const text = findExternalAgentsCheckbox().text();
      expect(text).toContain('Allow external agents');
      expect(text).toContain(
        'Users with the Maintainer or Owner role for a project can use external agents.',
      );
    });

    it('renders the custom flows label and help text', () => {
      const text = findFlowsCheckbox().text();
      expect(text).toContain('Allow custom flows');
      expect(text).toContain(
        'Users with the Maintainer or Owner role for a project can create new flows.',
      );
    });

    it('renders external agents between custom agents and custom flows', () => {
      const labels = findAllCheckboxes().wrappers.map((cb) => cb.text().split('\n')[0].trim());
      expect(labels[0]).toContain('Allow custom agents');
      expect(labels[1]).toContain('Allow external agents');
      expect(labels[2]).toContain('Allow custom flows');
    });

    it('does not render any cascading lock icons', () => {
      expect(findLockIcons()).toHaveLength(0);
    });
  });

  describe('checkbox state', () => {
    it('reflects customAgentsEnabled prop', () => {
      createComponent({ props: { customAgentsEnabled: false } });
      expect(findCustomAgentsCheckbox().attributes('checked')).toBeUndefined();
    });

    it('reflects customFlowsEnabled prop', () => {
      createComponent({ props: { customFlowsEnabled: false } });
      expect(findCustomFlowsCheckbox().attributes('checked')).toBeUndefined();
    });

    it('reflects externalAgentsEnabled prop', () => {
      createComponent({ props: { externalAgentsEnabled: false } });
      expect(findExternalAgentsCheckboxByTestId().attributes('checked')).toBeUndefined();
    });

    it('emits change-custom-agents when the agents checkbox toggles', () => {
      createComponent();
      findAgentsCheckbox().vm.$emit('input', false);
      expect(wrapper.emitted('change-custom-agents')).toEqual([[false]]);
      expect(wrapper.emitted('change-custom-flows')).toBeUndefined();
      expect(wrapper.emitted('change-external-agents')).toBeUndefined();
    });

    it('emits change-custom-flows when the flows checkbox toggles', () => {
      createComponent();
      findFlowsCheckbox().vm.$emit('input', false);
      expect(wrapper.emitted('change-custom-flows')).toEqual([[false]]);
      expect(wrapper.emitted('change-custom-agents')).toBeUndefined();
      expect(wrapper.emitted('change-external-agents')).toBeUndefined();
    });

    it('emits change-external-agents when the external agents checkbox toggles', () => {
      createComponent();
      findExternalAgentsCheckbox().vm.$emit('input', false);
      expect(wrapper.emitted('change-external-agents')).toEqual([[false]]);
      expect(wrapper.emitted('change-custom-agents')).toBeUndefined();
      expect(wrapper.emitted('change-custom-flows')).toBeUndefined();
    });
  });

  describe('disabled state', () => {
    it('disables all checkboxes when disabledCheckbox is true', () => {
      createComponent({ props: { disabledCheckbox: true } });
      expect(findCustomAgentsCheckbox().attributes('disabled')).toBeDefined();
      expect(findCustomFlowsCheckbox().attributes('disabled')).toBeDefined();
      expect(findExternalAgentsCheckboxByTestId().attributes('disabled')).toBeDefined();
    });

    describe('when custom agents are locked by ancestor', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            duoCustomAgentsCascadingSettings: { lockedByAncestor: true },
          },
        });
      });

      it('disables the custom agents checkbox only', () => {
        expect(findCustomAgentsCheckbox().attributes('disabled')).toBeDefined();
        expect(findCustomFlowsCheckbox().attributes('disabled')).toBeUndefined();
        expect(findExternalAgentsCheckboxByTestId().attributes('disabled')).toBeUndefined();
      });

      it('renders a single lock icon for custom agents', () => {
        expect(findLockIcons()).toHaveLength(1);
      });
    });

    describe('when custom flows are locked by application setting', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            duoCustomFlowsCascadingSettings: { lockedByApplicationSetting: true },
          },
        });
      });

      it('disables the custom flows checkbox only', () => {
        expect(findCustomFlowsCheckbox().attributes('disabled')).toBeDefined();
        expect(findCustomAgentsCheckbox().attributes('disabled')).toBeUndefined();
        expect(findExternalAgentsCheckboxByTestId().attributes('disabled')).toBeUndefined();
      });

      it('renders a single lock icon for custom flows', () => {
        expect(findLockIcons()).toHaveLength(1);
      });
    });

    describe('when external agents are locked by ancestor', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            duoExternalAgentsCascadingSettings: { lockedByAncestor: true },
          },
        });
      });

      it('disables the external agents checkbox only', () => {
        expect(findExternalAgentsCheckboxByTestId().attributes('disabled')).toBeDefined();
        expect(findCustomAgentsCheckbox().attributes('disabled')).toBeUndefined();
        expect(findCustomFlowsCheckbox().attributes('disabled')).toBeUndefined();
      });

      it('renders a single lock icon for external agents', () => {
        expect(findLockIcons()).toHaveLength(1);
      });
    });

    describe('when external agents are locked by application setting', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            duoExternalAgentsCascadingSettings: { lockedByApplicationSetting: true },
          },
        });
      });

      it('disables the external agents checkbox only', () => {
        expect(findExternalAgentsCheckboxByTestId().attributes('disabled')).toBeDefined();
      });

      it('renders a single lock icon for external agents', () => {
        expect(findLockIcons()).toHaveLength(1);
      });
    });
  });
});
