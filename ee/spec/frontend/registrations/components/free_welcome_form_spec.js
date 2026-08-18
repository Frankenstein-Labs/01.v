import { GlForm, GlFormFields, GlButton } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import FreeWelcomeForm from 'ee/registrations/components/free_welcome_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { COUNTRIES, STATES } from 'ee_jest/hand_raise_leads/components/mock_data';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('FreeWelcomeForm', () => {
  let wrapper;
  const submitPath = '/users/sign_up/welcome';
  const setupForCompanyLabel = 'Who will be using GitLab?';

  const defaultUserData = {
    firstName: 'John',
    lastName: 'Doe',
    showNameFields: false,
    companyName: 'Example Corp',
    country: 'US',
    state: 'NY',
    groupName: '',
    projectName: '',
    role: '',
    setupForCompany: '',
    registrationObjective: '',
  };

  const defaultRoleOptions = [
    { value: '0', text: 'Software Developer' },
    { value: '8', text: 'Other' },
  ];

  const defaultRegistrationObjectiveOptions = [
    { value: '0', text: 'I want to learn the basics of Git' },
    { value: '5', text: 'A different reason' },
  ];

  const createComponent = async ({
    userData = defaultUserData,
    countriesLoading = false,
    statesLoading = false,
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

    wrapper = shallowMountExtended(FreeWelcomeForm, {
      apolloProvider: createMockApollo([], mockResolvers),
      propsData: {
        userData,
        submitPath,
        namespaceId,
        roleOptions: defaultRoleOptions,
        registrationObjectiveOptions: defaultRegistrationObjectiveOptions,
        setupForCompanyLabel,
      },
      stubs: { GlButton },
    });

    if (!countriesLoading && !statesLoading) {
      await waitForPromises();
    }

    return wrapper;
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findMethodInput = () => wrapper.find('input[name="_method"]');
  const findContinueButton = () => wrapper.findByTestId('continue-button');
  const fieldsProps = () => findFormFields().props('fields');
  const formValues = () => findFormFields().props('modelValue') || wrapper.vm.formValues;

  describe('rendering', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('posts to the welcome path using the patch method', () => {
      expect(findForm().attributes('action')).toBe(submitPath);
      expect(findMethodInput().attributes('value')).toBe('patch');
    });

    it('renders the continue button', () => {
      expect(findContinueButton().exists()).toBe(true);
    });

    it('initializes form values from userData', () => {
      expect(formValues()).toMatchObject({
        company_name: 'Example Corp',
        country: 'US',
        state: 'NY',
        role: '',
        setup_for_company: '',
        registration_objective: '',
      });
    });

    it('passes role and registration objective options through to their fields', () => {
      expect(fieldsProps().role.options).toEqual(defaultRoleOptions);
      expect(fieldsProps().registration_objective.options).toEqual(
        defaultRegistrationObjectiveOptions,
      );
    });

    it('wires the setup_for_company label from props', () => {
      expect(fieldsProps().setup_for_company.label).toBe(setupForCompanyLabel);
    });
  });

  describe('country and state fields', () => {
    it('renders the state field when a state-requiring country is selected', async () => {
      await createComponent();

      expect(fieldsProps()).toHaveProperty('country');
      expect(fieldsProps()).toHaveProperty('state');
    });

    it('does not render the state field when no country is selected', async () => {
      await createComponent({ userData: { ...defaultUserData, country: '' } });

      expect(fieldsProps()).toHaveProperty('country');
      expect(fieldsProps()).not.toHaveProperty('state');
    });

    it('does not render the country field while countries are loading', async () => {
      await createComponent({ countriesLoading: true });

      expect(fieldsProps()).not.toHaveProperty('country');
    });

    it('does not render the state field while states are loading', async () => {
      await createComponent({ statesLoading: true });
      // countries resolve so the country field renders, while the states query stays pending
      await waitForPromises();

      expect(fieldsProps()).toHaveProperty('country');
      expect(fieldsProps()).not.toHaveProperty('state');
    });
  });

  describe('name fields', () => {
    it('renders the first and last name fields when showNameFields is true', async () => {
      await createComponent({ userData: { ...defaultUserData, showNameFields: true } });

      expect(fieldsProps()).toHaveProperty('first_name');
      expect(fieldsProps()).toHaveProperty('last_name');
    });

    it('does not render the first and last name fields when showNameFields is false', async () => {
      await createComponent({ userData: { ...defaultUserData, showNameFields: false } });

      expect(fieldsProps()).not.toHaveProperty('first_name');
      expect(fieldsProps()).not.toHaveProperty('last_name');
    });
  });

  describe('group name field', () => {
    it('is required when there is no namespace', async () => {
      await createComponent({ namespaceId: null });

      expect(fieldsProps().group_name.inputAttrs.disabled).toBe(false);
      expect(fieldsProps().group_name.validators).toHaveLength(1);
    });

    it('is disabled and not required when a namespace is provided', async () => {
      await createComponent({ namespaceId: 5 });

      expect(fieldsProps().group_name.inputAttrs.disabled).toBe(true);
      expect(fieldsProps().group_name.validators).toHaveLength(0);
    });
  });
});
