import { GlForm, GlFormFields, GlButton } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import TrialWelcomeForm from 'ee/registrations/components/trial_welcome_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { trackSaasTrialLeadSubmit } from 'ee/google_tag_manager';
import {
  COUNTRIES,
  STATES,
  COUNTRY_WITH_STATES,
  STATE,
} from 'ee_jest/hand_raise_leads/components/mock_data';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('ee/google_tag_manager', () => ({
  trackSaasTrialLeadSubmit: jest.fn(),
}));

Vue.use(VueApollo);

describe('TrialWelcomeForm', () => {
  let wrapper;
  const submitPath = '/trials/welcome';
  const gtmSubmitEventLabel = 'trial_welcome_form_submit';

  const defaultUserData = {
    firstName: 'John',
    lastName: 'Doe',
    showNameFields: false,
    companyName: 'Example Corp',
    country: 'US',
    state: 'NY',
    emailDomain: 'example.com',
    namespaceId: null,
    groupName: '',
    projectName: '',
    role: '',
    setupForCompany: '',
    registrationObjective: '',
  };

  const roleOptions = [
    { value: '0', text: 'Software Developer' },
    { value: '1', text: 'Development Team Lead' },
    { value: '2', text: 'Devops Engineer' },
    { value: '3', text: 'Systems Administrator' },
    { value: '4', text: 'Security Analyst' },
    { value: '5', text: 'Data Analyst' },
    { value: '6', text: 'Product Manager' },
    { value: '7', text: 'Product Designer' },
    { value: '8', text: 'Other' },
  ];

  const registrationObjectiveOptions = [
    { value: '0', text: 'I want to learn the basics of Git' },
    { value: '1', text: 'I want to move my repository to GitLab from somewhere else' },
    { value: '2', text: 'I want to store my code' },
    { value: '3', text: "I want to explore GitLab to see if it's worth switching to" },
    { value: '4', text: 'I want to use GitLab CI with my existing repository' },
    { value: '5', text: 'A different reason' },
  ];

  const createComponent = async ({
    userData = defaultUserData,
    countriesLoading = false,
    statesLoading = false,
    serverValidations = {},
    namespaceId,
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

    const component = shallowMountExtended(TrialWelcomeForm, {
      apolloProvider: createMockApollo([], mockResolvers),
      propsData: {
        userData,
        submitPath,
        gtmSubmitEventLabel,
        serverValidations,
        namespaceId,
        roleOptions,
        registrationObjectiveOptions,
      },
      stubs: {
        GlButton,
      },
    });

    if (!countriesLoading && !statesLoading) {
      await waitForPromises();
    }

    return component;
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findCountrySelect = () => wrapper.findComponentByTestId('country-dropdown');
  const findStateSelect = () => wrapper.findByTestId('state-dropdown');
  const findCompanyNameInput = () => wrapper.findComponent('[name="company_name"]');
  const findContinueButton = () => wrapper.findComponentByTestId('continue-button');
  const fieldsProps = () => findFormFields().props('fields');
  const formValues = () => findFormFields().props('modelValue') || wrapper.vm.formValues;

  describe('rendering', () => {
    describe('initialization', () => {
      it('initializes form values from userData prop', async () => {
        wrapper = await createComponent();

        expect(formValues()).toEqual({
          first_name: defaultUserData.firstName,
          last_name: defaultUserData.lastName,
          company_name: defaultUserData.companyName,
          country: defaultUserData.country,
          state: defaultUserData.state,
          group_name: defaultUserData.groupName,
          project_name: defaultUserData.projectName,
          namespace_id: defaultUserData.namespaceId,
          role: defaultUserData.role,
          setup_for_company: defaultUserData.setupForCompany,
          registration_objective: defaultUserData.registrationObjective,
        });
      });

      it('handles missing userData fields gracefully', async () => {
        wrapper = await createComponent({
          userData: {
            emailDomain: 'test.com',
          },
        });

        expect(formValues()).toEqual({
          first_name: undefined,
          last_name: undefined,
          company_name: undefined,
          country: undefined,
          state: undefined,
          namespace_id: null,
          group_name: '',
          project_name: '',
          role: '',
          setup_for_company: '',
          registration_objective: '',
        });
      });

      it('initializes selected country and state from userData', async () => {
        wrapper = await createComponent();

        expect(wrapper.vm.formValues.country).toBe(defaultUserData.country);
        expect(wrapper.vm.formValues.state).toBe(defaultUserData.state);
      });

      it('initializes group and project names as empty strings', async () => {
        wrapper = await createComponent();

        expect(wrapper.vm.formValues.group_name).toBe('');
        expect(wrapper.vm.formValues.project_name).toBe('');
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
          { key: 'company_name', name: 'company_name' },
          { key: 'country', name: undefined },
          { key: 'state', name: undefined },
          { key: 'role', name: undefined },
          { key: 'setup_for_company', name: undefined },
          { key: 'registration_objective', name: undefined },
        ];

        expectedFields.forEach(({ key, name }) => {
          if (fieldsProps()[key]) {
            if (name !== undefined && fieldsProps()[key].inputAttrs) {
              expect(fieldsProps()[key].inputAttrs).toHaveProperty('name', name);
            }
          }
        });
      });

      it('correctly updates GlFormFields values on input update', async () => {
        const initialValues = {
          first_name: defaultUserData.firstName,
          last_name: defaultUserData.lastName,
          company_name: defaultUserData.companyName,
          country: defaultUserData.country,
          state: defaultUserData.state,
          group_name: defaultUserData.groupName,
          project_name: defaultUserData.projectName,
          role: defaultUserData.role,
          setup_for_company: defaultUserData.setupForCompany,
          registration_objective: defaultUserData.registrationObjective,
          namespace_id: null,
        };
        expect(formValues()).toEqual(initialValues);

        const updatedValues = {
          ...initialValues,
          company_name: 'Updated Company Name',
        };

        findFormFields().vm.$emit('input', updatedValues);
        await nextTick();

        expect(wrapper.vm.formValues.company_name).toBe('Updated Company Name');
      });
    });

    describe('country field', () => {
      it('does not show country field when Apollo is loading countries', async () => {
        wrapper = await createComponent({ countriesLoading: true });
        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('country');
      });

      it('shows country field when Apollo is not loading countries', async () => {
        wrapper = await createComponent();
        await nextTick();

        expect(fieldsProps()).toHaveProperty('country');
      });
    });

    describe('state field', () => {
      it('does not show state field when Apollo is loading states', async () => {
        wrapper = await createComponent({ statesLoading: true });
        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('state');
      });

      it('shows state field when country requires states and states are loaded', async () => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, country: COUNTRY_WITH_STATES },
        });
        await nextTick();

        expect(fieldsProps()).toHaveProperty('state');
        expect(findStateSelect().exists()).toBe(true);
      });

      it('does not show state field when country does not require states', async () => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, country: 'NL' },
        });
        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('state');
      });

      it('does not show state field by default when no country is selected', async () => {
        wrapper = await createComponent({
          userData: { ...defaultUserData, country: '', state: '' },
        });
        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('state');
      });
    });

    describe('group and project name fields', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
      });

      it('always includes group name field with label', () => {
        expect(fieldsProps()).toHaveProperty('group_name');
        expect(fieldsProps().group_name.label).toBe('Group name');
      });

      it('always includes project name field with label', () => {
        expect(fieldsProps()).toHaveProperty('project_name');
        expect(fieldsProps().project_name.label).toBe('Project name');
      });

      it('updates group and project names when company name changes', () => {
        findCompanyNameInput().vm.$emit('input', 'company name');

        expect(formValues().group_name).toBe('company name-group');
        expect(formValues().project_name).toBe('company name-project');
      });

      it('does not clear group and project names when company name is cleared', () => {
        findCompanyNameInput().vm.$emit('input', 'company name');

        expect(formValues().group_name).toBe('company name-group');
        expect(formValues().project_name).toBe('company name-project');

        findCompanyNameInput().vm.$emit('input', '');

        expect(formValues().group_name).toBe('company name-group');
        expect(formValues().project_name).toBe('company name-project');
      });
    });

    describe('name fields', () => {
      describe('when showNameFields is true', () => {
        beforeEach(async () => {
          wrapper = await createComponent({
            userData: {
              ...defaultUserData,
              firstName: '',
              lastName: '',
              showNameFields: true,
            },
          });
        });

        it('renders first name field', () => {
          expect(fieldsProps()).toHaveProperty('first_name');
          expect(fieldsProps().first_name.label).toBe('First name');
          expect(fieldsProps().first_name.inputAttrs.name).toBe('first_name');
        });

        it('renders last name field', () => {
          expect(fieldsProps()).toHaveProperty('last_name');
          expect(fieldsProps().last_name.label).toBe('Last name');
          expect(fieldsProps().last_name.inputAttrs.name).toBe('last_name');
        });

        it('does not render hidden name inputs', () => {
          expect(wrapper.findByTestId('hidden-first-name').exists()).toBe(false);
          expect(wrapper.findByTestId('hidden-last-name').exists()).toBe(false);
        });
      });

      describe('when showNameFields is false', () => {
        beforeEach(async () => {
          wrapper = await createComponent({
            userData: {
              ...defaultUserData,
              firstName: 'John',
              lastName: 'Doe',
              showNameFields: false,
            },
          });
        });

        it('does not render first name field', () => {
          expect(fieldsProps()).not.toHaveProperty('first_name');
        });

        it('does not render last name field', () => {
          expect(fieldsProps()).not.toHaveProperty('last_name');
        });

        it('renders hidden first name input with correct value', () => {
          const hiddenInput = wrapper.findByTestId('hidden-first-name');
          expect(hiddenInput.exists()).toBe(true);
          expect(hiddenInput.attributes('value')).toBe('John');
          expect(hiddenInput.attributes('name')).toBe('first_name');
        });

        it('renders hidden last name input with correct value', () => {
          const hiddenInput = wrapper.findByTestId('hidden-last-name');
          expect(hiddenInput.exists()).toBe(true);
          expect(hiddenInput.attributes('value')).toBe('Doe');
          expect(hiddenInput.attributes('name')).toBe('last_name');
        });
      });
    });
  });

  describe('countries loading', () => {
    it('disables submit button', async () => {
      wrapper = await createComponent({ countriesLoading: true });

      expect(findCountrySelect().props('loading')).toBe(true);
      expect(findContinueButton().props('disabled')).toBe(true);
    });

    describe('countries successfully loaded', () => {
      describe('states loading', () => {
        it('disables submit button', async () => {
          wrapper = await createComponent({ statesLoading: true });

          expect(findCountrySelect().props('loading')).toBe(true);
          expect(findContinueButton().props('disabled')).toBe(true);
        });
      });

      describe('states successfully loaded', () => {
        it('enables submit button', async () => {
          wrapper = await createComponent();

          expect(findCountrySelect().props('loading')).toBe(false);
          expect(findContinueButton().props('disabled')).toBe(false);
        });
      });
    });
  });

  describe('field validations', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    describe('name field validations', () => {
      describe('when showNameFields is true', () => {
        beforeEach(async () => {
          wrapper = await createComponent({
            userData: {
              ...defaultUserData,
              showNameFields: true,
            },
          });
        });

        it.each`
          value     | result
          ${null}   | ${'First name is required.'}
          ${''}     | ${'First name is required.'}
          ${'John'} | ${''}
        `('validates first_name with value of `$value`', ({ value, result }) => {
          const firstNameValidator = fieldsProps().first_name.validators[0];
          expect(firstNameValidator(value)).toBe(result);
        });

        it.each`
          value    | result
          ${null}  | ${'Last name is required.'}
          ${''}    | ${'Last name is required.'}
          ${'Doe'} | ${''}
        `('validates last_name with value of `$value`', ({ value, result }) => {
          const lastNameValidator = fieldsProps().last_name.validators[0];
          expect(lastNameValidator(value)).toBe(result);
        });
      });
    });

    describe('company_name field validations', () => {
      it.each`
        value       | result
        ${null}     | ${'Company name is required.'}
        ${''}       | ${'Company name is required.'}
        ${'TestCo'} | ${''}
      `('validates the company_name with value of `$value`', ({ value, result }) => {
        const companyNameValidator = fieldsProps().company_name.validators[0];
        expect(companyNameValidator(value)).toBe(result);
      });
    });

    describe('group name field validations', () => {
      it('validates group name is required', async () => {
        wrapper = await createComponent();

        const groupNameValidator = fieldsProps().group_name.validators[0];

        expect(groupNameValidator('')).toBe('Group name is required.');
        expect(groupNameValidator('My Test Group')).toBe('');
      });
    });

    describe('project name field validations', () => {
      it('validates project name is required', async () => {
        wrapper = await createComponent();

        const projectNameValidator = fieldsProps().project_name.validators[0];

        expect(projectNameValidator('')).toBe('Project name is required.');
        expect(projectNameValidator('My Test Project')).toBe('');
      });
    });
  });

  describe('country and state field behavior', () => {
    it('shows and hides state field based on selected country', async () => {
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

  describe('personalization fields', () => {
    describe('role field', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
      });

      it('includes role field with correct options', () => {
        expect(fieldsProps()).toHaveProperty('role');
        expect(fieldsProps().role.label).toBe('Role');
        expect(fieldsProps().role.options).toHaveLength(9);
        expect(fieldsProps().role.options[0]).toEqual({
          value: '0',
          text: 'Software Developer',
        });
        expect(fieldsProps().role.options[8]).toEqual({
          value: '8',
          text: 'Other',
        });
      });

      it('has side-by-side layout class', () => {
        expect(fieldsProps().role.groupAttrs.class).toContain('md:gl-col-span-6');
      });

      it.each`
        value   | result
        ${null} | ${'Role is required.'}
        ${''}   | ${'Role is required.'}
        ${'0'}  | ${''}
        ${'5'}  | ${''}
      `('validates the role with value of `$value`', ({ value, result }) => {
        const roleValidator = fieldsProps().role.validators[0];
        expect(roleValidator(value)).toBe(result);
      });
    });

    describe('setup_for_company field', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
      });

      it('includes setup_for_company field with correct options', () => {
        expect(fieldsProps()).toHaveProperty('setup_for_company');
        expect(fieldsProps().setup_for_company.label).toBe('Who will be using GitLab?');
        expect(fieldsProps().setup_for_company.options).toHaveLength(2);
        expect(fieldsProps().setup_for_company.options[0]).toEqual({
          value: 'true',
          text: 'My team',
        });
        expect(fieldsProps().setup_for_company.options[1]).toEqual({
          value: 'false',
          text: 'Just me',
        });
      });

      it('has side-by-side layout class', () => {
        expect(fieldsProps().setup_for_company.groupAttrs.class).toContain('md:gl-col-span-6');
      });

      it.each`
        value      | result
        ${null}    | ${'This field is required.'}
        ${''}      | ${'This field is required.'}
        ${'true'}  | ${''}
        ${'false'} | ${''}
      `('validates the setup_for_company with value of `$value`', ({ value, result }) => {
        const setupValidator = fieldsProps().setup_for_company.validators[0];
        expect(setupValidator(value)).toBe(result);
      });
    });

    describe('registration_objective field', () => {
      beforeEach(async () => {
        wrapper = await createComponent();
      });

      it('includes registration_objective field with correct options', () => {
        expect(fieldsProps()).toHaveProperty('registration_objective');
        expect(fieldsProps().registration_objective.label).toBe(
          "What's your reason for joining GitLab?",
        );
        expect(fieldsProps().registration_objective.options).toHaveLength(6);
        expect(fieldsProps().registration_objective.options[0]).toEqual({
          value: '0',
          text: 'I want to learn the basics of Git',
        });
        expect(fieldsProps().registration_objective.options[5]).toEqual({
          value: '5',
          text: 'A different reason',
        });
      });

      it('has full-width layout class', () => {
        expect(fieldsProps().registration_objective.groupAttrs.class).toContain('gl-col-span-12');
      });

      it.each`
        value   | result
        ${null} | ${'This field is required.'}
        ${''}   | ${'This field is required.'}
        ${'0'}  | ${''}
        ${'1'}  | ${''}
        ${'4'}  | ${''}
      `('validates the registration_objective with value of `$value`', ({ value, result }) => {
        const objectiveValidator = fieldsProps().registration_objective.validators[0];
        expect(objectiveValidator(value)).toBe(result);
      });
    });

    it('initializes personalization fields from userData', async () => {
      wrapper = await createComponent({
        userData: {
          ...defaultUserData,
          role: '2',
          setupForCompany: 'true',
          registrationObjective: '4',
        },
      });

      expect(formValues().role).toBe('2');
      expect(formValues().setup_for_company).toBe('true');
      expect(formValues().registration_objective).toBe('4');
    });
  });

  describe('submitting', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
      await nextTick();
    });

    it('tracks the trial form submission and submits the form', async () => {
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

    describe('namespace create errors', () => {
      it('passes namespace create errors to GlFormFields when createErrors exist', async () => {
        const serverValidations = { group_name: ['Error msg'] };
        wrapper = await createComponent({ serverValidations });

        expect(findFormFields().props('serverValidations')).toEqual(serverValidations);
      });

      it('passes empty server validations to GlFormFields when valid', async () => {
        const serverValidations = {};
        wrapper = await createComponent({ serverValidations });

        expect(findFormFields().props('serverValidations')).toEqual(serverValidations);
      });
    });

    describe('with hidden namespace_id field', () => {
      it('value is rendered in hidden input and group name input is disabled', async () => {
        wrapper = await createComponent({ namespaceId: 1234 });

        const props = fieldsProps();

        expect(props.group_name.validators).toHaveLength(0);
        expect(props).toHaveProperty('namespace_id');
        expect(props.group_name.inputAttrs.disabled).toBe(true);
        expect(formValues().namespace_id).toBe(1234);
      });
    });
  });
});
