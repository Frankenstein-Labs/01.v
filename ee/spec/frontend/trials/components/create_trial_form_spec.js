import { GlForm, GlFormFields } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import CreateTrialForm from 'ee/trials/components/create_trial_form.vue';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import {
  COUNTRIES,
  STATES,
  COUNTRY_WITH_STATES,
  STATE,
} from 'ee_jest/hand_raise_leads/components/mock_data';
import { TRIAL_PHONE_DESCRIPTION } from 'ee/trials/constants';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('ee/google_tag_manager', () => ({
  trackSaasTrialLeadSubmit: jest.fn(),
}));

Vue.use(VueApollo);

describe('CreateTrialForm', () => {
  let wrapper;
  const submitPath = '/some/path';
  const gtmSubmitEventLabel = '_gtm_submit_event_label_';

  const defaultUserData = {
    firstName: 'Joe',
    lastName: 'Smith',
    companyName: 'ACME',
    country: 'US',
    state: 'CA',
    phoneNumber: '192919',
    emailDomain: 'example.com',
    showNameFields: true,
  };

  const items = [
    { text: 'Foo', value: '1' },
    { text: 'Bob', value: '2' },
  ];

  const defaultNamespaceData = {
    items,
    anyTrialEligibleNamespaces: true,
    initialValue: items[1].value,
  };

  const createComponent = async ({
    userData = defaultUserData,
    namespaceData = defaultNamespaceData,
    propsData = {},
    countriesLoading = false,
    statesLoading = false,
  } = {}) => {
    const mockResolvers = {
      Query: {
        countries() {
          if (countriesLoading) {
            return new Promise(() => {});
          }
          return COUNTRIES;
        },
        states() {
          if (statesLoading) {
            return new Promise(() => {});
          }
          return STATES;
        },
      },
    };

    const component = shallowMountExtended(CreateTrialForm, {
      apolloProvider: createMockApollo([], mockResolvers),
      propsData: {
        userData,
        namespaceData,
        submitPath,
        gtmSubmitEventLabel,
        border: true,
        canCreateGroup: true,
        ...propsData,
      },
      stubs: {
        ListboxInput,
      },
    });

    if (!countriesLoading && !statesLoading) {
      await waitForPromises();
    }

    return component;
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findCreateGroupButton = () => wrapper.findByTestId('footer-bottom-button');
  const findSubmitButton = () => wrapper.findComponentByTestId('submit-button');
  const findGroupListboxInput = () => wrapper.findComponentByTestId('namespace-dropdown');
  const findCountrySelect = () => wrapper.findComponentByTestId('country-dropdown');
  const findStateSelect = () => wrapper.findComponentByTestId('state-dropdown');
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const fieldsProps = () => findFormFields().props('fields');
  const findHiddenInput = (name) => wrapper.findByTestId(`hidden-${name}`);

  describe('rendering', () => {
    describe('initialization', () => {
      it('initializes items with create group option when createErrors exist', async () => {
        const createErrors = ['Group name already exists'];
        wrapper = await createComponent({
          namespaceData: {
            ...defaultNamespaceData,
            initialValue: '0',
            createErrors,
          },
        });

        const createOption = {
          value: '0',
          text: 'Create group',
        };
        const itemsWithCreateGroup = [createOption].concat(items);

        expect(findGroupListboxInput().props('items')).toEqual(itemsWithCreateGroup);
      });

      it('initializes items without create group option when no createErrors', async () => {
        wrapper = await createComponent({
          namespaceData: {
            ...defaultNamespaceData,
            createErrors: null,
          },
        });

        expect(findGroupListboxInput().props('items')).toEqual(items);
      });
    });

    describe('with default props', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
      });

      it('renders the form with correct action and method', () => {
        expect(findForm().attributes('action')).toBe(submitPath);
        expect(findForm().attributes('method')).toBe('post');
      });

      it('passes the correct fields to GlFormFields', () => {
        expect(findFormFields().exists()).toBe(true);

        const expectedFields = [
          { key: 'first_name', name: 'first_name' },
          { key: 'last_name', name: 'last_name' },
          { key: 'company_name', name: 'company_name' },
          { key: 'country', name: undefined },
          { key: 'state', name: undefined },
          { key: 'phone_number', name: 'phone_number' },
        ];

        expectedFields.forEach(({ key, name }) => {
          expect(fieldsProps()).toHaveProperty(key);

          if (name !== undefined) {
            expect(fieldsProps()[key].inputAttrs).toHaveProperty('name', name);
          }
        });
      });

      it('correctly binds formValues to GlFormFields via v-model', async () => {
        expect(findFormFields().props('values')).toEqual(wrapper.vm.formValues);

        const updatedValues = {
          ...wrapper.vm.formValues,
          company_name: 'New Company Name',
        };

        findFormFields().vm.$emit('input', updatedValues);
        await nextTick();

        expect(findFormFields().props('values')).toEqual(updatedValues);
      });
    });

    describe('group selector', () => {
      it('exists as a field', async () => {
        wrapper = await createComponent();

        expect(fieldsProps()).toHaveProperty('group');
      });

      it('is set with initial value', async () => {
        wrapper = await createComponent();

        await nextTick();

        expect(wrapper.vm.formValues.group).toBe(defaultNamespaceData.initialValue);
      });

      it('is unset when initialValue is null', async () => {
        wrapper = await createComponent({
          namespaceData: { ...defaultNamespaceData, initialValue: '' },
        });

        expect(wrapper.vm.formValues.group).toBe('');
      });

      it('does not exist when there are no eligible namespaces', async () => {
        wrapper = await createComponent({
          namespaceData: { ...defaultNamespaceData, anyTrialEligibleNamespaces: false },
        });

        expect(fieldsProps()).not.toHaveProperty('group');
      });

      describe('create group button', () => {
        it('shows create group button when a regular group is selected', async () => {
          wrapper = await createComponent({
            namespaceData: {
              ...defaultNamespaceData,
              initialValue: '2',
            },
          });

          expect(findCreateGroupButton().exists()).toBe(true);
          expect(findCreateGroupButton().text()).toBe('Create group');
        });

        it('hides create group button when create group option is selected', async () => {
          wrapper = await createComponent({
            namespaceData: {
              ...defaultNamespaceData,
              initialValue: '0',
            },
          });

          expect(findCreateGroupButton().exists()).toBe(false);
        });

        it('shows create group button when no group is initially selected', async () => {
          wrapper = await createComponent({
            namespaceData: {
              ...defaultNamespaceData,
              initialValue: '',
            },
          });

          expect(findCreateGroupButton().exists()).toBe(true);
        });

        it('handles create group button click correctly', async () => {
          wrapper = await createComponent({
            namespaceData: {
              ...defaultNamespaceData,
              initialValue: '2',
            },
          });

          await nextTick();

          expect(wrapper.vm.formValues.group).toBe('2');
          expect(findCreateGroupButton().exists()).toBe(true);

          const updatedValues = {
            ...wrapper.vm.formValues,
            group: '0',
          };
          findFormFields().vm.$emit('input', updatedValues);
          await nextTick();

          expect(wrapper.vm.formValues.group).toBe('0');
          expect(findGroupListboxInput().props('items')[0].text).toBe('Create group');
        });

        it('removes create group option when group changes from create group to another option', async () => {
          wrapper = await createComponent({
            namespaceData: {
              ...defaultNamespaceData,
              initialValue: '2',
            },
          });

          await nextTick();

          const createGroupValues = {
            ...wrapper.vm.formValues,
            group: '0',
          };
          findFormFields().vm.$emit('input', createGroupValues);
          await nextTick();

          expect(wrapper.vm.formValues.group).toBe('0');
          expect(findGroupListboxInput().props('items')).toHaveLength(items.length + 1);
          expect(findGroupListboxInput().props('items')[0].text).toBe('Create group');

          const regularGroupValues = {
            ...wrapper.vm.formValues,
            group: '2',
          };
          findFormFields().vm.$emit('input', regularGroupValues);
          await nextTick();

          expect(wrapper.vm.formValues.group).toBe('2');
          expect(findGroupListboxInput().props('items')).toEqual(items);
        });
      });
    });

    describe('new group name field', () => {
      it('shows new group name field when there are no eligible namespaces', async () => {
        wrapper = await createComponent({
          namespaceData: {
            ...defaultNamespaceData,
            anyTrialEligibleNamespaces: false,
          },
        });

        expect(fieldsProps()).toHaveProperty('new_group_name');
      });

      it('shows new group name field when create group option is selected', async () => {
        wrapper = await createComponent({
          namespaceData: {
            ...defaultNamespaceData,
            initialValue: '0',
          },
        });

        expect(fieldsProps()).toHaveProperty('new_group_name');
      });

      it('does not show new group name field when eligible namespaces exist and different group is selected', async () => {
        wrapper = await createComponent({
          namespaceData: {
            ...defaultNamespaceData,
            anyTrialEligibleNamespaces: true,
            initialValue: '2',
          },
        });

        expect(fieldsProps()).not.toHaveProperty('new_group_name');
      });
    });

    describe('namespace create errors', () => {
      it('passes namespace create errors to GlFormFields when createErrors exist', async () => {
        const createErrors = ['Group name already exists'];

        wrapper = await createComponent({
          namespaceData: {
            ...defaultNamespaceData,
            createErrors,
          },
        });

        expect(findFormFields().props('serverValidations')).toEqual({
          new_group_name: createErrors,
        });
      });

      it('passes empty server validations to GlFormFields when no createErrors', async () => {
        wrapper = await createComponent({
          namespaceData: {
            ...defaultNamespaceData,
            createErrors: null,
          },
        });

        expect(findFormFields().props('serverValidations')).toEqual({
          new_group_name: null,
        });
      });
    });

    describe('with hidden name fields', () => {
      beforeEach(async () => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, showNameFields: false },
        });
      });

      it('does not include name fields in fields prop when showNameFields is false', () => {
        expect(fieldsProps()).not.toHaveProperty('first_name');
        expect(fieldsProps()).not.toHaveProperty('last_name');

        expect(findHiddenInput('first-name').attributes('value')).toBe(defaultUserData.firstName);
        expect(findHiddenInput('last-name').attributes('value')).toBe(defaultUserData.lastName);
      });
    });

    describe('country field', () => {
      it('returns false when Apollo is loading countries', async () => {
        wrapper = await createComponent({ countriesLoading: true });

        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('country');
      });

      it('returns true when Apollo is not loading countries', async () => {
        wrapper = await createComponent();

        await nextTick();

        expect(fieldsProps()).toHaveProperty('country');
      });
    });

    describe('state field', () => {
      it('returns false when Apollo is loading states', async () => {
        wrapper = await createComponent({ statesLoading: true });

        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('state');
      });

      it('returns true when Apollo is not loading states', async () => {
        wrapper = await createComponent();

        await nextTick();

        expect(fieldsProps()).toHaveProperty('state');
      });
    });
  });

  describe('countries loading', () => {
    it('disables submit button', async () => {
      wrapper = await createComponent({ countriesLoading: true });

      expect(findCountrySelect().props('loading')).toBe(true);
      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    describe('countries successfully loaded', () => {
      describe('states loading', () => {
        it('disables submit button', async () => {
          wrapper = await createComponent({ statesLoading: true });

          expect(findCountrySelect().props('loading')).toBe(true);
          expect(findSubmitButton().props('disabled')).toBe(true);
        });
      });

      describe('states successfully loaded', () => {
        it('enables submit button', async () => {
          wrapper = await createComponent();

          expect(findCountrySelect().props('loading')).toBe(false);
          expect(findSubmitButton().props('disabled')).toBe(false);
        });
      });
    });
  });

  describe('field validations', () => {
    describe('group field validations', () => {
      it('returns an error if group is not selected', async () => {
        wrapper = await createComponent({
          namespaceData: { ...defaultNamespaceData, initialValue: '' },
        });

        const groupValidator = fieldsProps().group.validators[0];
        expect(groupValidator(wrapper.vm.formValues.group)).toBe(
          'Please select a group for your trial.',
        );
      });

      it('returns no error if group is selected', async () => {
        wrapper = await createComponent();

        const groupValidator = fieldsProps().group.validators[0];
        expect(groupValidator(wrapper.vm.formValues.group)).toBe('');
      });
    });

    describe('new group name field validations', () => {
      it('includes proper validation for new group name field', async () => {
        wrapper = await createComponent({
          namespaceData: {
            ...defaultNamespaceData,
            anyTrialEligibleNamespaces: false,
          },
        });

        const newGroupNameValidator = fieldsProps().new_group_name.validators[0];

        expect(newGroupNameValidator('')).toBe('You must enter a new group name.');
        expect(newGroupNameValidator('My new Group')).toBe('');
      });
    });

    describe('name field validations', () => {
      it.each`
        value     | result
        ${null}   | ${'First name is required.'}
        ${''}     | ${'First name is required.'}
        ${'John'} | ${''}
      `('validates the first_name with value of `$value`', async ({ value, result }) => {
        wrapper = await createComponent();

        const firstNameValidator = fieldsProps().first_name.validators[0];
        expect(firstNameValidator(value)).toBe(result);
      });

      it.each`
        value    | result
        ${null}  | ${'Last name is required.'}
        ${''}    | ${'Last name is required.'}
        ${'Doe'} | ${''}
      `('validates the last_name with value of `$value`', async ({ value, result }) => {
        wrapper = await createComponent();

        const lastNameValidator = fieldsProps().last_name.validators[0];
        expect(lastNameValidator(value)).toBe(result);
      });
    });

    describe('company_name field validations', () => {
      it.each`
        value     | result
        ${null}   | ${'Company name is required.'}
        ${''}     | ${'Company name is required.'}
        ${'Acme'} | ${''}
      `('validates the company_name with value of `$value`', async ({ value, result }) => {
        wrapper = await createComponent();

        const companyNameValidator = fieldsProps().company_name.validators[0];
        expect(companyNameValidator(value)).toBe(result);
      });
    });

    describe('phone_number validations', () => {
      it.each`
        value                          | result
        ${'+1 (121) 22-12-23'}         | ${TRIAL_PHONE_DESCRIPTION}
        ${'+12190AX '}                 | ${TRIAL_PHONE_DESCRIPTION}
        ${'Tel:129120'}                | ${TRIAL_PHONE_DESCRIPTION}
        ${'11290+12'}                  | ${TRIAL_PHONE_DESCRIPTION}
        ${'++1121221223'}              | ${TRIAL_PHONE_DESCRIPTION}
        ${'+1121221223'}               | ${''}
        ${defaultUserData.phoneNumber} | ${''}
        ${''}                          | ${''}
      `('validates the phone number with value of `$value`', async ({ value, result }) => {
        wrapper = await createComponent();

        const phoneValidator = fieldsProps().phone_number.validators[0];

        expect(phoneValidator(value)).toBe(result);
      });
    });
  });

  describe('country and state field behavior', () => {
    it('renders country and state fields after countries are loaded', async () => {
      wrapper = await createComponent();
      await nextTick();

      expect(findCountrySelect().props('items').length).toBeGreaterThan(1);
      expect(findStateSelect().props('items').length).toBeGreaterThan(1);
    });

    it('has the proper state show and hide logic based on the selected country', async () => {
      wrapper = await createComponent();
      await nextTick();

      const updatedValuesNL = {
        ...wrapper.vm.formValues,
        country: 'NL',
      };

      findFormFields().vm.$emit('input', updatedValuesNL);
      await nextTick();

      expect(fieldsProps()).not.toHaveProperty('state');

      const updatedValuesUS = {
        ...wrapper.vm.formValues,
        country: COUNTRY_WITH_STATES,
      };
      findFormFields().vm.$emit('input', updatedValuesUS);
      await nextTick();

      expect(fieldsProps()).toHaveProperty('state');
    });

    it.each`
      selectedCountry        | selectedState | stateFieldExists | result
      ${COUNTRY_WITH_STATES} | ${null}       | ${true}          | ${'State or province is required.'}
      ${'NL'}                | ${null}       | ${false}         | ${''}
      ${COUNTRY_WITH_STATES} | ${STATE}      | ${true}          | ${''}
    `(
      'validates state with selectedCountry=$selectedCountry and selectedState=$selectedState',
      async ({ selectedCountry, selectedState, stateFieldExists, result }) => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, country: selectedCountry, state: selectedState },
        });

        const hasStateField = 'state' in fieldsProps();

        expect(hasStateField).toBe(stateFieldExists);

        if (hasStateField) {
          const stateValidator = fieldsProps().state.validators[0];
          expect(stateValidator(selectedState)).toBe(result);
        }
      },
    );

    it.each`
      countryValue | result
      ${''}        | ${'Country or region is required.'}
      ${null}      | ${'Country or region is required.'}
      ${'US'}      | ${''}
      ${'NL'}      | ${''}
    `('validates country with value=$countryValue', async ({ countryValue, result }) => {
      wrapper = await createComponent({
        userData: { ...defaultUserData, country: countryValue },
      });

      const countryValidator = fieldsProps().country.validators[0];
      expect(countryValidator(countryValue)).toBe(result);
    });
  });

  describe('submitting', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
      await nextTick();

      findFormFields().vm.$emit('input', wrapper.vm.formValues);
    });

    it('tracks the saas Trial submitting', async () => {
      const submitSpy = jest.fn();
      const formElement = wrapper.vm.$refs.form.$el;
      formElement.submit = submitSpy;

      findFormFields().vm.$emit('submit');
      await nextTick();

      expect(trackSaasTrialLeadSubmit).toHaveBeenCalledWith(
        gtmSubmitEventLabel,
        defaultUserData.emailDomain,
      );

      expect(submitSpy).toHaveBeenCalled();
    });
  });
});
