import { GlForm, GlFormFields, GlSprintf, GlLink, GlFormCheckbox } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import CreateTrialForm from 'ee/pages/gitlab_subscriptions/self_managed/trials/components/create_trial_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';
import { COUNTRIES, STATES } from 'ee_jest/hand_raise_leads/components/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { PROMO_URL } from '~/constants';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

Vue.use(VueApollo);

describe('CreateTrialForm', () => {
  let wrapper;
  const submitPath = '/test/cdot/marketo_trial';

  const defaultUserData = {
    firstName: 'John',
    lastName: 'Doe',
    emailAddress: 'john@example.com',
  };

  const createComponent = async ({
    userData = defaultUserData,
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
      apolloProvider: createMockApollo([], mockResolvers, {}),
      propsData: {
        userData,
        submitPath,
        ...propsData,
      },
      stubs: {
        ListboxInput,
        GlSprintf,
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
  const findSubmitButton = () => wrapper.findComponentByTestId('submit-button');
  const findConsentCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const fieldsProps = () => findFormFields().props('fields');
  const formValues = () => wrapper.vm.formValues;

  describe('rendering', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    it('renders the form with correct action and method', () => {
      expect(findForm().attributes('action')).toBe(submitPath);
      expect(findForm().attributes('method')).toBe('post');
    });

    it('renders all form fields with default values from userData prop', () => {
      expect(formValues()).toEqual({
        first_name: defaultUserData.firstName,
        last_name: defaultUserData.lastName,
        email_address: defaultUserData.emailAddress,
        company_name: '',
        country: '',
        state: '',
        consent_to_marketing: '',
      });
    });

    it('renders the submit button', () => {
      expect(findSubmitButton().isVisible()).toBe(true);
      expect(findSubmitButton().text()).toBe('Get started');
    });

    it('renders the consent to marketing checkbox and defaults it to checked', () => {
      expect(wrapper.findByTestId('consent-checkbox').isVisible()).toBe(true);

      const hiddenInput = wrapper.find('input[name="consent_to_marketing"]');
      expect(hiddenInput.exists()).toBe(true);
      expect(hiddenInput.element.value).toBe('1');
    });

    it('renders terms and conditions text with links', () => {
      const links = wrapper.findAllComponents(GlLink);

      const subLink = links.at(0);
      expect(subLink.text()).toContain('GitLab Subscription Agreement');
      expect(subLink.attributes('href')).toBe(`${PROMO_URL}/handbook/legal/subscription-agreement`);

      const privacyLink = links.at(1);
      expect(privacyLink.text()).toContain('Privacy Statement');
      expect(privacyLink.attributes('href')).toBe(`${PROMO_URL}/privacy`);
    });
  });

  describe('form initialization', () => {
    it('initializes form values with empty strings when user data is missing', async () => {
      wrapper = await createComponent({
        userData: {
          firstName: '',
          lastName: '',
          emailAddress: '',
        },
      });

      expect(wrapper.vm.formValues.first_name).toBe('');
      expect(wrapper.vm.formValues.last_name).toBe('');
      expect(wrapper.vm.formValues.email_address).toBe('');
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
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    it.each`
      value     | result
      ${null}   | ${'First name is required.'}
      ${''}     | ${'First name is required.'}
      ${'John'} | ${''}
    `('validates first_name with value of `$value`', ({ value, result }) => {
      const validator = fieldsProps().first_name.validators[0];
      expect(validator(value)).toBe(result);
    });

    it.each`
      value    | result
      ${null}  | ${'Last name is required.'}
      ${''}    | ${'Last name is required.'}
      ${'Doe'} | ${''}
    `('validates last_name with value of `$value`', ({ value, result }) => {
      const validator = fieldsProps().last_name.validators[0];
      expect(validator(value)).toBe(result);
    });

    it.each`
      value                 | result
      ${null}               | ${'Email address is required.'}
      ${''}                 | ${'Email address is required.'}
      ${'john@example.com'} | ${''}
    `('validates email_address with value of `$value`', ({ value, result }) => {
      const validator = fieldsProps().email_address.validators[0];
      expect(validator(value)).toBe(result);
    });

    it.each`
      value     | result
      ${null}   | ${'Company name is required.'}
      ${''}     | ${'Company name is required.'}
      ${'ACME'} | ${''}
    `('validates company_name with value of `$value`', ({ value, result }) => {
      const validator = fieldsProps().company_name.validators[0];
      expect(validator(value)).toBe(result);
    });

    it.each`
      value   | result
      ${''}   | ${'Country or region is required.'}
      ${null} | ${'Country or region is required.'}
      ${'US'} | ${''}
    `('validates country with value of `$value`', ({ value, result }) => {
      const validator = fieldsProps().country.validators[0];
      expect(validator(value)).toBe(result);
    });
  });

  describe('form submission', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    it('submits the form when submit button is clicked', async () => {
      const submitSpy = jest.fn();
      wrapper.vm.$refs.form.$el.submit = submitSpy;

      findFormFields().vm.$emit('submit');
      await nextTick();

      expect(submitSpy).toHaveBeenCalled();
    });

    it('includes authenticity token in form submission', () => {
      const csrfInput = wrapper.find('input[name="authenticity_token"]');
      expect(csrfInput.exists()).toBe(true);
    });
  });

  describe('form values binding', () => {
    it('correctly binds formValues to GlFormFields via v-model', async () => {
      wrapper = await createComponent();

      expect(findFormFields().props('values')).toEqual(wrapper.vm.formValues);

      const updatedValues = {
        ...wrapper.vm.formValues,
        company_name: 'New Company',
      };

      findFormFields().vm.$emit('input', updatedValues);
      await nextTick();

      expect(findFormFields().props('values')).toEqual(updatedValues);
    });
  });

  describe('internal events tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();
    let trackEventSpy;

    beforeEach(async () => {
      wrapper = await createComponent();
      ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
    });

    it('tracks sm_trial_create_form_render on mount', () => {
      expect(trackEventSpy).toHaveBeenCalledWith('sm_trial_create_form_render', {}, undefined);
    });

    it('tracks sm_trial_create_form_submit_click when form is submitted', async () => {
      const submitSpy = jest.fn();
      wrapper.vm.$refs.form.$el.submit = submitSpy;

      findFormFields().vm.$emit('submit');
      await nextTick();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'sm_trial_create_form_submit_click',
        {},
        undefined,
      );
    });

    it('tracks sm_trial_create_form_uncheck_consent when consent checkbox is unchecked', async () => {
      findConsentCheckbox().vm.$emit('change', '0');
      await nextTick();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'sm_trial_create_form_uncheck_consent',
        {},
        undefined,
      );
    });

    it('does not track consent event when checkbox is checked', async () => {
      findConsentCheckbox().vm.$emit('change', '1');
      await nextTick();

      expect(trackEventSpy).not.toHaveBeenCalledWith(
        'sm_trial_create_form_uncheck_consent',
        {},
        undefined,
      );
    });
  });
});
