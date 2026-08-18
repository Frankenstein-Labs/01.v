import { GlForm, GlFormInput, GlInputGroupText } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { HTTP_STATUS_BAD_REQUEST, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';

import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import countriesResolver from 'ee/subscriptions/graphql/resolvers';

import InternationalPhoneInput from 'ee/users/identity_verification/components/international_phone_input.vue';
import GlCountdown from '~/vue_shared/components/gl_countdown.vue';

import {
  I18N_PHONE_NUMBER_LENGTH_ERROR,
  I18N_PHONE_NUMBER_NAN_ERROR,
  I18N_PHONE_NUMBER_BLANK_ERROR,
} from 'ee/users/identity_verification/constants';

import { COUNTRIES, mockCountry1, mockCountry2 } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

useMockLocationHelper();

describe('International Phone input component', () => {
  let wrapper;
  let axiosMock;

  const SEND_CODE_PATH = '/users/identity_verification/send_phone_verification_code';

  const findForm = () => wrapper.findComponent(GlForm);

  const findCountryFormGroup = () => wrapper.findByTestId('country-form-group');
  const findCountrySelect = () => wrapper.findComponentByTestId('country-form-select');

  const findPhoneNumberFormGroup = () => wrapper.findByTestId('phone-number-form-group');
  const findPhoneNumberInput = () => wrapper.findComponent(GlFormInput);
  const findInternationalDialCode = () => wrapper.findComponent(GlInputGroupText);
  const findCountdown = () => wrapper.findComponent(GlCountdown);

  const countryText = (country) =>
    `${country.flag} ${country.name} (+${country.internationalDialCode})`;

  const enterPhoneNumber = (value) => findPhoneNumberInput().vm.$emit('input', value);
  const submitForm = () => findForm().vm.$emit('submit', { preventDefault: jest.fn() });

  const findSubmitButton = () => wrapper.findByTestId('submit-btn');

  const createMockApolloProvider = () => {
    const mockResolvers = { countriesResolver };
    const mockApollo = createMockApollo([], mockResolvers);

    mockApollo.clients.defaultClient.cache.writeQuery({
      query: countriesQuery,
      data: { countries: COUNTRIES },
    });
    return mockApollo;
  };

  const createComponent = (
    { provide, props } = {
      provide: {},
      props: {},
    },
    mountFn = shallowMountExtended,
  ) => {
    wrapper = mountFn(InternationalPhoneInput, {
      apolloProvider: createMockApolloProvider(),
      propsData: {
        sendCodeAllowed: true,
        sendCodeAllowedAfter: '2000-01-01T00:00:00Z',
        ...props,
      },
      provide: {
        phoneSendCodePath: SEND_CODE_PATH,
        phoneNumber: {
          ...provide,
        },
      },
    });
  };

  beforeEach(() => {
    createComponent();
    axiosMock = new MockAdapter(axios);
  });

  afterEach(() => {
    axiosMock.restore();
    createAlert.mockClear();
  });

  describe('Country select field', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should have label', () => {
      expect(findCountryFormGroup().attributes('label')).toBe('Country or region');
    });

    it('renders a country selector listbox', () => {
      expect(findCountrySelect().props()).toMatchObject({
        searchable: true,
        block: true,
        items: [
          {
            value: mockCountry1.id,
            text: countryText(mockCountry1),
            name: mockCountry1.name,
            internationalDialCode: mockCountry1.internationalDialCode,
          },
          {
            value: mockCountry2.id,
            text: countryText(mockCountry2),
            name: mockCountry2.name,
            internationalDialCode: mockCountry2.internationalDialCode,
          },
        ],
      });
    });

    it('should have default set to US', () => {
      expect(findCountrySelect().attributes('selected')).toBe('US');
      expect(findCountrySelect().props('toggleText')).toBe(countryText(mockCountry1));
    });

    it('should render international dial code', () => {
      createComponent({}, mountExtended);

      expect(findInternationalDialCode().text()).toBe(`+${mockCountry1.internationalDialCode}`);
    });

    it('filters the country list on user search', async () => {
      findCountrySelect().vm.$emit('search', 'AU');
      await nextTick();

      expect(findCountrySelect().props('items')).toEqual([
        {
          value: 'AU',
          text: countryText(mockCountry2),
          name: mockCountry2.name,
          internationalDialCode: mockCountry2.internationalDialCode,
        },
      ]);
    });

    it('updates country field with the name of selected country', async () => {
      createComponent({}, mountExtended);

      findCountrySelect().vm.$emit('select', 'AU');
      await nextTick();

      expect(findCountrySelect().props('toggleText')).toBe(countryText(mockCountry2));
      expect(findInternationalDialCode().text()).toBe(`+${mockCountry2.internationalDialCode}`);
    });

    it('should render injected value', () => {
      createComponent({ provide: { country: 'AU' } });

      expect(findCountrySelect().attributes('selected')).toBe('AU');
      expect(findCountrySelect().props('toggleText')).toBe(countryText(mockCountry2));
    });
  });

  describe('Phone number input field', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should have label', () => {
      expect(findPhoneNumberFormGroup().attributes('label')).toBe('Phone number');
    });

    it('should be of type tel', () => {
      expect(findPhoneNumberInput().attributes('type')).toBe('tel');
    });

    it.each`
      value              | valid    | errorMessage
      ${'1800134678'}    | ${true}  | ${''}
      ${'123456789012'}  | ${true}  | ${''}
      ${'1234567890123'} | ${false} | ${I18N_PHONE_NUMBER_LENGTH_ERROR}
      ${'1300-123-123'}  | ${false} | ${I18N_PHONE_NUMBER_NAN_ERROR}
      ${'abc'}           | ${false} | ${I18N_PHONE_NUMBER_NAN_ERROR}
      ${''}              | ${false} | ${I18N_PHONE_NUMBER_BLANK_ERROR}
    `(
      'when the input has a value of $value, then its validity should be $valid',
      async ({ value, valid, errorMessage }) => {
        enterPhoneNumber(value);

        await nextTick();

        const expectedState = valid ? 'true' : undefined;

        expect(findPhoneNumberFormGroup().attributes('invalid-feedback')).toBe(errorMessage);
        expect(findPhoneNumberFormGroup().attributes('state')).toBe(expectedState);

        expect(findPhoneNumberInput().attributes('state')).toBe(expectedState);

        const expectedButtonState = valid ? undefined : 'true';
        expect(findSubmitButton().attributes().disabled).toBe(expectedButtonState);
      },
    );

    it('should render injected value', () => {
      const number = '555';
      createComponent({ provide: { number } });
      expect(findPhoneNumberInput().attributes('value')).toBe(number);
    });
  });

  describe('Submit button', () => {
    describe('when send is allowed', () => {
      it('does not render "Send code in" text and a GlCountdown', () => {
        createComponent({}, mountExtended);

        expect(wrapper.findByText(/Send code in/).exists()).toBe(false);
        expect(findCountdown().exists()).toBe(false);
      });
    });

    describe('when send is not allowed', () => {
      beforeEach(() => {
        jest
          .spyOn(Date, 'now')
          .mockImplementation(() => new Date('2000-01-01T00:00:00Z').getTime());

        createComponent(
          { props: { sendCodeAllowed: false, sendCodeAllowedAfter: '2000-01-01T01:02:03Z' } },
          mountExtended,
        );
      });

      it('renders the correct text and GlCountdown', () => {
        expect(wrapper.findByText(/Send code in/).exists()).toBe(true);
        expect(findCountdown().exists()).toBe(true);
      });

      it('is disabled', async () => {
        enterPhoneNumber('1800134678');
        await nextTick();

        expect(findSubmitButton().attributes('aria-disabled')).toBe('true');
      });

      describe('when GlCountdown emits a "timer-expired" event', () => {
        it('emits re-emits the event', () => {
          findCountdown().vm.$emit('timer-expired');

          expect(wrapper.emitted('timer-expired')).toStrictEqual([[]]);
        });
      });
    });
  });

  describe('Sending verification code', () => {
    describe('when request is successful', () => {
      const data = { success: true, send_allowed_after: '2000-01-01T01:02:03Z' };

      beforeEach(() => {
        axiosMock.onPost(SEND_CODE_PATH).reply(HTTP_STATUS_OK, data);

        createComponent({ props: { additionalRequestParams: { captcha_token: '1234' } } });

        enterPhoneNumber('555');
        submitForm();
        return waitForPromises();
      });

      it('emits `verification-attempt` event', () => {
        expect(wrapper.emitted('verification-attempt')).toHaveLength(1);
      });

      it('posts correct data with additional request params', () => {
        expect(axiosMock.history.post[0].data).toBe(
          JSON.stringify({
            country: 'US',
            international_dial_code: '1',
            phone_number: '555',
            captcha_token: '1234',
          }),
        );
      });

      it('emits next event with the correct payload', () => {
        expect(wrapper.emitted('next')).toStrictEqual([
          [
            {
              country: 'US',
              internationalDialCode: '1',
              number: '555',
              sendAllowedAfter: data.send_allowed_after,
            },
          ],
        ]);
      });
    });

    describe('when request is unsuccessful', () => {
      const errorMessage = 'Invalid phone number';
      const reason = 'bad_request';

      beforeEach(() => {
        axiosMock
          .onPost(SEND_CODE_PATH)
          .reply(HTTP_STATUS_BAD_REQUEST, { message: errorMessage, reason });

        enterPhoneNumber('555');
        submitForm();
        return waitForPromises();
      });

      it('emits `verification-attempt` event', () => {
        expect(wrapper.emitted('verification-attempt')).toHaveLength(1);
      });

      it('renders error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: errorMessage,
          captureError: true,
          error: expect.any(Error),
        });
      });
    });

    describe('when TeleSign is down', () => {
      const errorMessage = 'Something went wrong';
      const reason = 'unknown_telesign_error';

      beforeEach(() => {
        axiosMock
          .onPost(SEND_CODE_PATH)
          .reply(HTTP_STATUS_BAD_REQUEST, { message: errorMessage, reason });

        enterPhoneNumber('555');
        submitForm();
        return waitForPromises();
      });

      it('emits the skip-verification event', () => {
        expect(wrapper.emitted('skip-verification')).toHaveLength(1);
      });

      it('does not emit `verification-attempt` event', () => {
        expect(wrapper.emitted('verification-attempt')).toBeUndefined();
      });
    });

    describe('when user is related to a previously banned user', () => {
      const errorMessage = 'Your account is blocked';
      const reason = 'related_to_banned_user';

      beforeEach(() => {
        axiosMock
          .onPost(SEND_CODE_PATH)
          .reply(HTTP_STATUS_BAD_REQUEST, { message: errorMessage, reason });

        enterPhoneNumber('555');
        submitForm();
        return waitForPromises();
      });

      it('disables the submit button', () => {
        expect(findSubmitButton().attributes().disabled).toBe('true');
      });

      it('renders error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: errorMessage,
          captureError: true,
          error: expect.any(Error),
        });
      });
    });

    describe('when user is high risk', () => {
      const errorMessage = 'Phone verification high-risk user';
      const reason = 'related_to_high_risk_user';

      beforeEach(() => {
        axiosMock
          .onPost(SEND_CODE_PATH)
          .reply(HTTP_STATUS_BAD_REQUEST, { message: errorMessage, reason });

        submitForm();
        return waitForPromises();
      });

      it('reloads the window', () => {
        expect(window.location.reload).toHaveBeenCalled();
      });
    });

    describe('Captcha', () => {
      describe('when disableSubmitButton is true', () => {
        beforeEach(() => {
          createComponent({
            props: { disableSubmitButton: true },
          });

          enterPhoneNumber('555');
          return waitForPromises();
        });

        it('should disable the submit button', () => {
          expect(findSubmitButton().attributes().disabled).toBe('true');
        });
      });
    });
  });
});
