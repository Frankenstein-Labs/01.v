import {
  GlAccordion,
  GlAccordionItem,
  GlButton,
  GlCollapsibleListbox,
  GlLink,
  GlIcon,
  GlSprintf,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VariablesOverrideList from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_override_list.vue';
import VariablesOverrideModal from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_override_modal.vue';
import {
  ALLOW,
  DEFAULT_VARIABLES_OVERRIDE_STATE,
  DENY,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import { stubComponent } from 'helpers/stub_component';

describe('VariablesOverrideList', () => {
  let wrapper;

  const showModalWindowSpy = jest.fn();

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(VariablesOverrideList, {
      propsData,
      stubs: {
        GlSprintf,
        VariablesOverrideModal: stubComponent(VariablesOverrideModal, {
          methods: {
            showModalWindow: showModalWindowSpy,
          },
        }),
      },
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findLink = () => wrapper.findComponent(GlLink);
  const findButton = () => wrapper.findComponent(GlButton);
  const findModal = () => wrapper.findComponent(VariablesOverrideModal);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findValidationMessage = () => wrapper.findByTestId('validation-message');

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders accordion with correct title', () => {
      expect(findAccordion().exists()).toBe(true);
      expect(findAccordionItem().props('title')).toBe('Variable option');
      expect(findAccordionItem().props('visible')).toBe(false);
      expect(findValidationMessage().exists()).toBe(false);
      expect(findIcon().exists()).toBe(false);
    });

    it('renders collapsible listbox with default values', () => {
      expect(findCollapsibleListbox().exists()).toBe(true);
      expect(findCollapsibleListbox().props('selected')).toBe(DENY);
    });

    it('renders help link', () => {
      expect(findLink().exists()).toBe(true);
      expect(findLink().attributes('href')).toBe(VariablesOverrideList.HELP_PAGE_LINK);
      expect(findLink().attributes('target')).toBe('_blank');
    });

    it('renders button with correct text', () => {
      expect(findButton().exists()).toBe(true);
      expect(findButton().text()).toContain('Edit allowlist (0 variables)');
    });

    it('renders modal component', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props('exceptions')).toEqual(['']);
      expect(findModal().props('isVariablesOverrideAllowed')).toBe(false);
    });

    it.each`
      'visible' | 'expectedPayload'
      ${false}  | ${undefined}
      ${true}   | ${[[DEFAULT_VARIABLES_OVERRIDE_STATE]]}
    `(
      'sets default variable configuration when initially opened',
      async ({ visible, expectedPayload }) => {
        await findAccordionItem().vm.$emit('input', visible);

        expect(wrapper.emitted('select')).toEqual(expectedPayload);
      },
    );
  });

  describe('with provided variables override', () => {
    const variablesOverride = {
      allowed: true,
      exceptions: ['CI_VARIABLE_1', 'CI_VARIABLE_2'],
    };

    beforeEach(() => {
      createComponent({ propsData: { variablesOverride, isNewPolicy: false } });
    });

    it('renders collapsible listbox with allowed value', () => {
      expect(findAccordionItem().props('visible')).toBe(true);
      expect(findCollapsibleListbox().props('selected')).toBe(ALLOW);
    });

    it('renders button with correct text for allowlist', () => {
      expect(findButton().text()).toContain('Edit denylist (2 variables)');
    });

    it('passes correct props to modal', () => {
      expect(findModal().props('exceptions')).toEqual(variablesOverride.exceptions);
      expect(findModal().props('isVariablesOverrideAllowed')).toBe(true);
    });
  });

  describe('with empty exceptions array', () => {
    const variablesOverride = {
      allowed: false,
      exceptions: [],
    };

    beforeEach(() => {
      createComponent({ propsData: { variablesOverride } });
    });

    it('passes default empty string to modal', () => {
      expect(findModal().props('exceptions')).toEqual(['']);
    });
  });

  describe('interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows modal when button is clicked', () => {
      findButton().vm.$emit('click');

      expect(showModalWindowSpy).toHaveBeenCalled();
    });

    it('emits select event when list type is changed', () => {
      findCollapsibleListbox().vm.$emit('select', ALLOW);

      expect(wrapper.emitted('select')).toEqual([
        [{ ...DEFAULT_VARIABLES_OVERRIDE_STATE, allowed: true }],
      ]);
    });

    it('emits select event when exceptions are selected', () => {
      const exceptions = ['CI_VARIABLE_1'];
      findModal().vm.$emit('select-exceptions', exceptions);

      expect(wrapper.emitted('select')).toEqual([[{ exceptions }]]);
    });
  });

  describe('validation of structure', () => {
    const invalidKeyVariablesOverride = {
      invalid_key: false,
      exceptions: [],
    };

    const invalidValueVariablesOverride = {
      allowed: 'invalid_value',
      exceptions: [],
    };

    it.each([invalidKeyVariablesOverride, invalidValueVariablesOverride])(
      'renders validation message when variables configuration is invalid',
      (variablesOverride) => {
        createComponent({
          propsData: {
            variablesOverride,
          },
        });

        expect(findIcon().props('name')).toBe('error');
        expect(findValidationMessage().exists()).toBe(true);
        expect(findValidationMessage().text()).toBe(
          'Variables override configuration has invalid structure.',
        );
      },
    );
  });
});
