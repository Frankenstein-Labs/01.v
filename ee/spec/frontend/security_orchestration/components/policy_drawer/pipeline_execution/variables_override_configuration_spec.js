import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VariablesOverrideConfiguration from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/variables_override_configuration.vue';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';
import { DEFAULT_VARIABLES_OVERRIDE_STATE } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';

describe('VariablesOverrideList', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(VariablesOverrideConfiguration, {
      propsData: {
        ...props,
      },
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findStatusHeader = () => wrapper.findByTestId('status-header');
  const findToggleList = () => wrapper.findComponent(ToggleList);

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render accordion when there are no exceptions', () => {
      expect(findAccordion().exists()).toBe(false);
      expect(findStatusHeader().text()).toBe(
        'Settings from outside of the policy cannot override variables when the policy runs.',
      );
      expect(findToggleList().exists()).toBe(false);
    });

    it('uses DEFAULT_VARIABLES_OVERRIDE_STATE when no props are provided', () => {
      expect(wrapper.props('variablesOverride')).toEqual(DEFAULT_VARIABLES_OVERRIDE_STATE);
    });
  });

  describe('when in allowlist mode', () => {
    const denylistProps = {
      variablesOverride: {
        allowed: false,
        exceptions: ['CI_VARIABLE_1', 'CI_VARIABLE_2'],
      },
    };

    beforeEach(() => {
      createComponent(denylistProps);
    });

    it('displays the allowlist header', () => {
      expect(findAccordionItem().props('title')).toBe('Allowlist details');
    });

    it('displays the denied message', () => {
      expect(findStatusHeader().text()).toBe(
        'Settings from outside of the policy cannot override variables when the policy runs, except for the variables defined in the allowlist.',
      );
    });

    it('displays the exceptions list', () => {
      expect(findToggleList().props('items')).toHaveLength(2);
      expect(findToggleList().props('items')[0]).toBe('CI_VARIABLE_1');
      expect(findToggleList().props('items')[1]).toBe('CI_VARIABLE_2');
    });
  });

  describe('when in denylist mode', () => {
    const allowlistProps = {
      variablesOverride: {
        allowed: true,
        exceptions: ['CI_VARIABLE_3'],
      },
    };

    beforeEach(() => {
      createComponent(allowlistProps);
    });

    it('displays the denylist header', () => {
      expect(findAccordionItem().props('title')).toBe('Denylist details');
    });

    it('displays the allow message', () => {
      expect(findStatusHeader().text()).toBe(
        'Settings from outside of the policy can override variables when the policy runs, except the variables defined in the denylist.',
      );
    });

    it('displays the exceptions list', () => {
      expect(findToggleList().props('items')).toHaveLength(1);
      expect(findToggleList().props('items')[0]).toBe('CI_VARIABLE_3');
    });
  });

  describe('when in allowlist mode with no exceptions', () => {
    beforeEach(() => {
      createComponent({ variablesOverride: { allowed: true } });
    });
    it('renders the allowed message with no exceptions', () => {
      expect(findStatusHeader().text()).toBe(
        'Settings from outside of the policy can override variables when the policy runs.',
      );
    });
  });

  describe('when in denylist mode with no exceptions', () => {
    beforeEach(() => {
      createComponent({ variablesOverride: { allowed: false } });
    });
    it('renders the denied message with no exceptions', () => {
      expect(findStatusHeader().text()).toBe(
        'Settings from outside of the policy cannot override variables when the policy runs.',
      );
    });
  });

  describe('when no exceptions are provided', () => {
    const noExceptionsProps = {
      variablesOverride: {
        allowed: true,
        exceptions: [],
      },
    };

    beforeEach(() => {
      createComponent(noExceptionsProps);
    });

    it('does not render an empty exceptions list', () => {
      expect(findToggleList().exists()).toBe(false);
    });
  });

  describe('when exceptions is undefined', () => {
    const undefinedExceptionsProps = {
      variablesOverride: {
        allowed: true,
      },
    };

    beforeEach(() => {
      createComponent(undefinedExceptionsProps);
    });

    it('handles undefined exceptions gracefully', () => {
      expect(findToggleList().exists()).toBe(false);
    });
  });
});
