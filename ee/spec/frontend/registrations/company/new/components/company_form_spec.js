import { GlButton, GlForm, GlFormFields } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trackCompanyForm } from 'ee/google_tag_manager';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  COUNTRIES,
  COUNTRY_WITH_STATES,
  STATE,
  STATES,
} from 'ee_jest/hand_raise_leads/components/mock_data';
import { TRIAL_PHONE_DESCRIPTION } from 'ee/trials/constants';
import { mockTracking } from 'helpers/tracking_helper';

const SUBMIT_PATH = '_submit_path_';

jest.mock('ee/google_tag_manager');

Vue.use(VueApollo);

describe('CompanyForm', () => {
  let wrapper;

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

  const createComponent = async ({
    user = defaultUserData,
    provideData = {},
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

    const component = shallowMountExtended(CompanyForm, {
      apolloProvider: createMockApollo([], mockResolvers),
      provide: {
        submitPath: SUBMIT_PATH,
        user,
        trackActionForErrors: '_trackActionForErrors_',
        trialDuration: 30,
        showFormFooter: true,
        ...provideData,
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

  const findSubmitButton = () => wrapper.findComponent(GlButton);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const fieldsProps = () => findFormFields().props('fields');
  const findCountrySelect = () => wrapper.findComponentByTestId('country-dropdown');
  const findStateSelect = () => wrapper.findComponentByTestId('state-dropdown');
  const findHiddenInput = (name) => wrapper.findByTestId(`hidden-${name}`);
  const findFooterDescriptionText = () => wrapper.findByTestId('footer_description_text');

  describe('rendering', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
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

  describe('with hidden name fields', () => {
    beforeEach(async () => {
      wrapper = await createComponent({
        user: { ...defaultUserData, showNameFields: false },
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

      const updatedValues = { ...wrapper.vm.formValues, country: 'NL' };
      findFormFields().vm.$emit('input', updatedValues);
      await nextTick();

      expect(fieldsProps()).not.toHaveProperty('state');

      const updatedValuesWithStates = { ...wrapper.vm.formValues, country: COUNTRY_WITH_STATES };
      findFormFields().vm.$emit('input', updatedValuesWithStates);
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
          user: { ...defaultUserData, country: selectedCountry, state: selectedState },
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
        user: { ...defaultUserData, country: countryValue },
      });

      const countryValidator = fieldsProps().country.validators[0];
      expect(countryValidator(countryValue)).toBe(result);
    });
  });

  describe('field validations', () => {
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

    describe('tracking', () => {
      let trackingSpy;

      beforeEach(async () => {
        wrapper = await createComponent();
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      it('does not track when valid', () => {
        findFormFields().vm.$emit('field-validation', { fieldName: 'first_name', state: true });

        expect(trackingSpy).not.toHaveBeenCalled();
      });

      it('tracks when invalid', () => {
        findFormFields().vm.$emit('field-validation', {
          fieldName: 'first_name',
          state: false,
          invalidFeedback: 'do not show',
        });

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'track__trackActionForErrors__error', {
          label: 'first_name_is_invalid',
        });
      });
    });
  });

  describe('when showFormFooter is false', () => {
    beforeEach(async () => {
      wrapper = await createComponent({ provideData: { showFormFooter: false } });
    });

    it('displays correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Continue');
    });

    it('does not display footer', () => {
      expect(findFooterDescriptionText().exists()).toBe(false);
    });
  });

  describe('when showFormFooter is true', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    it('displays correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Continue with trial');
    });

    it('displays correct footer text', () => {
      expect(findFooterDescriptionText().exists()).toBe(true);
      expect(findFooterDescriptionText().text()).toBe(
        'Try GitLab Ultimate and automate tasks with GitLab Duo Agent Platform free for 30 days. After that, continue with free features or upgrade to a paid plan.',
      );
    });
  });

  describe('submitting', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    it('has a submit button', () => {
      expect(findSubmitButton().attributes('type')).toBe('submit');
    });

    it('displays form with correct action', () => {
      expect(findForm().attributes('action')).toBe(SUBMIT_PATH);
    });

    it('tracks form submission', async () => {
      const submitSpy = jest.fn();
      const formElement = wrapper.vm.$refs.form.$el;
      formElement.submit = submitSpy;

      findFormFields().vm.$emit('submit');
      await nextTick();

      expect(trackCompanyForm).toHaveBeenCalledWith('ultimate_trial', 'example.com');

      expect(submitSpy).toHaveBeenCalled();
    });
  });
});
