import { GlForm, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';

import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import GlCountdown from '~/vue_shared/components/gl_countdown.vue';
import { sprintf } from '~/locale';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { HTTP_STATUS_BAD_REQUEST, HTTP_STATUS_OK } from '~/lib/utils/http_status';

import { createAlert, VARIANT_SUCCESS } from '~/alert';

import VerifyPhoneVerificationCode from 'ee/users/identity_verification/components/verify_phone_verification_code.vue';
import {
  I18N_VERIFICATION_CODE_NAN_ERROR,
  I18N_VERIFICATION_CODE_BLANK_ERROR,
  CONTACT_SUPPORT_URL,
} from 'ee/users/identity_verification/constants';

jest.mock('~/alert');

describe('Verify phone verification code input component', () => {
  let wrapper;
  let axiosMock;

  const COUNTRY = 'US';
  const INTERNATIONAL_DIAL_CODE = '1';
  const NUMBER = '555';

  const SEND_CODE_PATH = '/users/identity_verification/send_phone_verification_code';
  const VERIFY_CODE_PATH = '/users/identity_verification/verify_phone_verification_code';

  const findForm = () => wrapper.findComponent(GlForm);

  const findVerificationCodeFormGroup = () => wrapper.findByTestId('verification-code-form-group');
  const findVerificationCodeInput = () =>
    wrapper.findComponentByTestId('verification-code-form-input');

  const findVerifyCodeButton = () => wrapper.findByTestId('verify-btn');
  const findGoBackLink = () => wrapper.findComponentByTestId('go-back-btn');
  const findContactSupportLink = () => wrapper.findByTestId('contact-support-link');

  const enterCode = (value) => findVerificationCodeInput().vm.$emit('input', value);
  const submitForm = () => findForm().vm.$emit('submit', { preventDefault: jest.fn() });

  const findResendCodeButton = () => wrapper.findComponentByTestId('resend-code-link');
  const resendCode = () => findResendCodeButton().vm.$emit('click');

  const findCountdown = () => wrapper.findComponent(GlCountdown);

  const createComponent = ({ props, provide } = { props: {}, provide: {} }) => {
    wrapper = shallowMountExtended(VerifyPhoneVerificationCode, {
      propsData: {
        latestPhoneNumber: {
          country: COUNTRY,
          internationalDialCode: INTERNATIONAL_DIAL_CODE,
          number: NUMBER,
        },
        sendCodeAllowed: true,
        sendCodeAllowedAfter: '2000-01-01T00:00:00Z',
        ...props,
      },
      provide: {
        phoneSendCodePath: SEND_CODE_PATH,
        phoneVerifyCodePath: VERIFY_CODE_PATH,
        ...provide,
      },
      stubs: {
        GlSprintf,
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

  it('contains a link to contact support', () => {
    expect(findContactSupportLink().attributes('href')).toEqual(CONTACT_SUPPORT_URL);
    expect(wrapper.text()).toContain(
      'Having trouble? Send a new code, enter a new phone number, or contact support.',
    );
  });

  describe('Verification Code input field', () => {
    it('should have label', () => {
      expect(findVerificationCodeFormGroup().attributes('label')).toBe('Verification code');
    });

    it('puts description text outside', () => {
      const findLabelDescription = () => wrapper.findByTestId('label-description');

      expect(findLabelDescription().text()).toContain(
        sprintf("We've sent a verification code to +%{phoneNumber}", {
          phoneNumber: INTERNATIONAL_DIAL_CODE + NUMBER,
        }),
      );
    });

    it('should be of type number', () => {
      expect(findVerificationCodeInput().attributes('type')).toBe('number');
    });

    it('opts out of password-manager autofill without dropping one-time-code', () => {
      // The SMS code is a one-time code, so it stays annotated as one for the browser's own
      // autofill; only the extensions that would offer a stored TOTP are opted out.
      expect(findVerificationCodeInput().attributes('autocomplete')).toBe('one-time-code');
      expect(findVerificationCodeInput().attributes('data-1p-ignore')).toBe('true');
      expect(findVerificationCodeInput().attributes('data-bwignore')).toBe('true');
      expect(findVerificationCodeInput().attributes('data-form-type')).toBe('other');
      expect(findVerificationCodeInput().attributes('data-lpignore')).toBe('true');
    });

    it.each`
      value       | valid    | errorMessage
      ${'123456'} | ${true}  | ${''}
      ${'abc'}    | ${false} | ${I18N_VERIFICATION_CODE_NAN_ERROR}
      ${''}       | ${false} | ${I18N_VERIFICATION_CODE_BLANK_ERROR}
    `(
      'when the input has a value of $value, then its validity should be $valid',
      async ({ value, valid, errorMessage }) => {
        enterCode(value);

        await nextTick();

        const expectedState = valid ? 'true' : undefined;
        const expectedButtonState = valid ? undefined : 'true';

        expect(findVerificationCodeFormGroup().attributes('invalid-feedback')).toBe(errorMessage);
        expect(findVerificationCodeFormGroup().attributes('state')).toBe(expectedState);

        expect(findVerificationCodeInput().attributes('state')).toBe(expectedState);

        expect(findVerifyCodeButton().attributes().disabled).toBe(expectedButtonState);
      },
    );
  });

  describe('Go back to enter another phone number link', () => {
    beforeEach(() => {
      findGoBackLink().vm.$emit('click');
      return nextTick();
    });

    it('emits back event', () => {
      expect(wrapper.emitted('back')).toHaveLength(1);
    });

    it('resets form', () => {
      expect(findVerificationCodeFormGroup().attributes('invalid-feedback')).toBe('');
      expect(findVerificationCodeFormGroup().attributes('state')).toBe(undefined);

      expect(findVerificationCodeInput().attributes('value')).toBe('');
      expect(findVerificationCodeInput().attributes('state')).toBe(undefined);

      expect(findVerifyCodeButton().attributes('disabled')).toBeDefined();
    });
  });

  describe('Re-sending code', () => {
    describe('when send is allowed', () => {
      it('does not render "Send a new code in" text and a GlCountdown', () => {
        expect(wrapper.findByText(/Send a new code in/).exists()).toBe(false);
        expect(findCountdown().exists()).toBe(false);
      });
    });

    describe('when send is not allowed', () => {
      beforeEach(() => {
        jest
          .spyOn(Date, 'now')
          .mockImplementation(() => new Date('2000-01-01T00:00:00Z').getTime());

        createComponent({
          props: { sendCodeAllowed: false, sendCodeAllowedAfter: '2000-01-01T01:02:03Z' },
        });
      });

      it('contains a link to contact support', () => {
        expect(findContactSupportLink().attributes('href')).toEqual(CONTACT_SUPPORT_URL);
        expect(wrapper.text()).toContain(
          'Having trouble? Send a new code in , enter a new phone number, or contact support.',
        );
      });

      it('renders the correct text and GlCountdown', () => {
        expect(wrapper.findByText(/Send a new code in/).exists()).toBe(true);
        expect(findCountdown().exists()).toBe(true);
      });

      it('does not render the resend code link', () => {
        expect(wrapper.findByTestId('resend-code-link').exists()).toBe(false);
      });

      describe('when GlCountdown emits a "timer-expired" event', () => {
        it('emits re-emits the event', () => {
          findCountdown().vm.$emit('timer-expired');

          expect(wrapper.emitted('timer-expired')).toStrictEqual([[]]);
        });
      });
    });

    describe('when request is successful', () => {
      const data = { success: true, send_allowed_after: '2000-01-01T01:02:03Z' };

      beforeEach(() => {
        axiosMock.onPost(SEND_CODE_PATH).reply(HTTP_STATUS_OK, data);

        createComponent({ props: { additionalRequestParams: { captcha_token: '1234' } } });

        resendCode();
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

      it('emits `resent` event with the correct data', () => {
        expect(wrapper.emitted('resent')).toStrictEqual([[data.send_allowed_after]]);
      });

      it('renders success message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: sprintf('We sent a new code to +%{phoneNumber}', {
            phoneNumber: INTERNATIONAL_DIAL_CODE + NUMBER,
          }),
          variant: VARIANT_SUCCESS,
        });
      });
    });

    describe('when request is unsuccessful', () => {
      beforeEach(() => {
        axiosMock
          .onPost(SEND_CODE_PATH)
          .reply(HTTP_STATUS_BAD_REQUEST, { message: 'Something went wrong' });

        resendCode();
        return waitForPromises();
      });

      it('emits `verification-attempt` event', () => {
        expect(wrapper.emitted('verification-attempt')).toHaveLength(1);
      });

      it('renders error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong',
          captureError: true,
          error: expect.any(Error),
        });
      });
    });
  });

  describe('Verifying code', () => {
    describe('when request is successful', () => {
      beforeEach(() => {
        axiosMock.onPost(VERIFY_CODE_PATH).reply(HTTP_STATUS_OK, { success: true });

        createComponent({ props: { additionalRequestParams: { captcha_token: '1234' } } });

        enterCode('123');
        submitForm();
        return waitForPromises();
      });

      it('posts correct data with additional request params', () => {
        expect(axiosMock.history.post[0].data).toBe(
          JSON.stringify({
            verification_code: '123',
            captcha_token: '1234',
          }),
        );
      });

      it('does not emit `verification-attempt` event', () => {
        expect(wrapper.emitted('verification-attempt')).toBeUndefined();
      });

      it('emits next event with user entered phone number', () => {
        expect(wrapper.emitted('verified')).toHaveLength(1);
      });
    });

    describe('when request is unsuccessful', () => {
      const errorMessage = 'Enter a valid code';
      const reason = 'bad_request';

      beforeEach(() => {
        axiosMock
          .onPost(VERIFY_CODE_PATH)
          .reply(HTTP_STATUS_BAD_REQUEST, { message: errorMessage, reason });

        enterCode('000');
        submitForm();
        return waitForPromises();
      });

      it('emits `verification-attempt` event', () => {
        expect(wrapper.emitted('verification-attempt')).toHaveLength(1);
      });

      it('renders error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Enter a valid code',
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
          .onPost(VERIFY_CODE_PATH)
          .reply(HTTP_STATUS_BAD_REQUEST, { message: errorMessage, reason });

        enterCode('000');
        submitForm();
        return waitForPromises();
      });

      it('emits the verified event', () => {
        expect(wrapper.emitted('verified')).toHaveLength(1);
      });
    });

    describe('Captcha', () => {
      describe('when disableSubmitButton is true', () => {
        beforeEach(() => {
          createComponent({
            props: {
              disableSubmitButton: true,
            },
          });

          enterCode('000');
          return waitForPromises();
        });

        it('should disable the verify, go back and resend buttons', () => {
          expect(findVerifyCodeButton().attributes().disabled).toBe('true');
          expect(findGoBackLink().exists()).toBe(false);
          expect(findResendCodeButton().exists()).toBe(false);
        });
      });

      describe('when arkose challenge is shown and solved', () => {
        beforeEach(() => {
          createComponent({
            props: {
              arkoseChallengeShown: true,
              arkoseChallengeSolved: true,
            },
          });

          enterCode('000');
          return waitForPromises();
        });

        it('should enable the verify, go back and resend buttons', () => {
          expect(findVerifyCodeButton().attributes('disabled')).toBe(undefined);
          expect(findGoBackLink().exists()).toBe(true);
          expect(findResendCodeButton().exists()).toBe(true);
        });
      });
    });
  });
});
